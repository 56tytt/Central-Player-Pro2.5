
use gst::prelude::*;
use gstreamer as gst;
use gstreamer::glib;
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
#[allow(dead_code)]
#[derive(Debug, Clone, PartialEq)]
pub enum PlayerState {
    Stopped,
    Loading,
    Playing,
    Paused,
}

#[derive(Debug, Clone)]
pub enum AudioCommand {
    LoadFile(String),
    Play,
    Pause,
    Stop,
    SetVolume(f64),
    Seek(f32),
    Shutdown,
    SetEq(usize, f64),
}

#[derive(Debug, Clone)]
pub enum AudioStatus {
    StateChanged(PlayerState),
    PositionUpdated(f64),
    DurationUpdated(f64),
    Error(String),
    EndOfStream,
}

pub struct AudioEngine {
    command_tx: Sender<AudioCommand>,
    event_rx: Receiver<AudioStatus>,
    worker: Option<JoinHandle<()>>,

    pub current_state: PlayerState,
    pub current_duration: f64,
    pub current_position: f64,
    pub spectrum_data: Arc<Mutex<Vec<f32>>>,
}

impl AudioEngine {
    pub fn new_headless() -> Self {
        gst::init().expect("Failed to init GStreamer");

        let (cmd_tx, cmd_rx) = mpsc::channel();
        let (event_tx, event_rx) = mpsc::channel();

        let handle = thread::spawn(move || {
            run_loop(cmd_rx, event_tx); // <-- מחקנו את ctx מכאן!
        });

        Self {
            command_tx: cmd_tx,
            event_rx,
            worker: Some(handle),
            current_state: PlayerState::Stopped,
            current_duration: 0.0,
            current_position: 0.0,
            spectrum_data: Arc::new(Mutex::new(Vec::new())),
        }
    }


    pub fn update_eq(&self, bands: [f32; 10]) {
        for (i, val) in bands.iter().enumerate() {
            // שולח פקודה לעדכן את הבאנד הספציפי (0-9)
            let _ = self.command_tx.send(AudioCommand::SetEq(i, *val as f64));
        }
    }

    pub fn load(&self, path: &str) {
        let uri = if path.starts_with("file://") {
            path.to_string()
        } else {
            match glib::filename_to_uri(path, None) {
                Ok(u) => u.to_string(),
                Err(e) => {
                    eprintln!("URI conversion error: {}", e);
                    return;
                }
            }
        };

        let _ = self.command_tx.send(AudioCommand::LoadFile(uri));
    }

    pub fn play(&self) {
        let _ = self.command_tx.send(AudioCommand::Play);
    }

    pub fn set_eq(&self, band_idx: usize, gain: f64) {
        let _ = self.command_tx.send(AudioCommand::SetEq(band_idx, gain));
    }

    pub fn pause(&self) {
        let _ = self.command_tx.send(AudioCommand::Pause);
    }
    #[allow(dead_code)]
    pub fn stop(&self) {
        let _ = self.command_tx.send(AudioCommand::Stop);
    }

    pub fn set_volume(&self, volume_percent: f32) {
        let v = (volume_percent as f64).clamp(0.0, 1.0);
        let _ = self.command_tx.send(AudioCommand::SetVolume(v));
    }

    pub fn seek(&self, percent: f32) {
        let percent = percent.clamp(0.0, 100.0);
        let _ = self.command_tx.send(AudioCommand::Seek(percent));
    }

    pub fn update(&mut self) -> bool {
        let mut finished = false;

        // 1. קריאת הודעות מה-Thread
        loop {
            match self.event_rx.try_recv() {
                Ok(AudioStatus::PositionUpdated(p)) => self.current_position = p,
                Ok(AudioStatus::DurationUpdated(d)) => self.current_duration = d,
                Ok(AudioStatus::StateChanged(s)) => self.current_state = s,
                Ok(AudioStatus::EndOfStream) => {
                    self.current_state = PlayerState::Stopped;
                    self.current_position = 0.0;
                    finished = true;
                }
                Ok(AudioStatus::Error(e)) => eprintln!("Audio error: {}", e),
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => break,
            }
        }

        // 2. סימולציה סופר-חלקה (Smooth Visualization) 🌊
        if self.current_state == PlayerState::Playing {
            if let Ok(mut data) = self.spectrum_data.lock() {
                if data.len() != 40 {
                    *data = vec![0.0; 40];
                }

                let time = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs_f64();

                for i in 0..40 {
                    let x = i as f64 * 0.2;
                    let wave1 = (time * 8.0 + x).sin();
                    let wave2 = (time * 4.0 - x * 1.5).cos();
                    let wave3 = ((time * 2.0) + (i as f64 * 0.5)).sin();

                    let combined = (wave1 + wave2 + wave3).abs() / 3.0;
                    let target_val = -50.0 + (combined * 50.0);
                    data[i] = data[i] * 0.8 + (target_val as f32) * 0.2;
                }
            }
        } else {
            // ניקוי הדרגתי כשהשיר עוצר
            if let Ok(mut data) = self.spectrum_data.lock()
                && !data.is_empty()
            {
                let mut all_silent = true;
                for val in data.iter_mut() {
                    *val -= 2.0;
                    if *val > -60.0 {
                        all_silent = false;
                    } else {
                        *val = -60.0;
                    }
                }
                if all_silent {
                    data.clear();
                }
            }
        }

        finished
    }
}

impl Drop for AudioEngine {
    fn drop(&mut self) {
        let _ = self.command_tx.send(AudioCommand::Shutdown);
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}

// =========================================================
// Run Loop - המנוע שרץ ברקע
// =========================================================
fn run_loop(cmd_rx: Receiver<AudioCommand>, event_tx: Sender<AudioStatus>) {
    // 1. יצירת ה-Playbin
    let pipeline = match gst::ElementFactory::make("playbin").build() {
        Ok(p) => p,
        Err(e) => {
            let _ = event_tx.send(AudioStatus::Error(format!(
                "Failed to create playbin: {}",
                e
            )));
            return;
        }
    };

    let fakesink = gst::ElementFactory::make("fakesink")
        .build()
        .expect("Failed to create fakesink");

    // אומרים למנוע: "כל וידאו שאתה מוצא, תזרוק לפח הזה אל תפתח חלון!"
    pipeline.set_property("video-sink", &fakesink);

    // 2. יצירת האקולייזר וחיבורו (תוקן: אין יותר כפילות)
    let equalizer = gst::ElementFactory::make("equalizer-10bands")
        .build()
        .expect("Missing gst-plugins-good");
    fakesink.set_property("sync", true);

    // חיבור האקולייזר לנגן
    pipeline.set_property("audio-filter", &equalizer);

    let bus = match pipeline.bus() {
        Some(b) => b,
        None => return,
    };

    let mut current_state = PlayerState::Stopped;
    let mut last_update = std::time::Instant::now();

    loop {
        // --- טיפול בפקודות ---
        while let Ok(cmd) = cmd_rx.try_recv() {
            match cmd {
                AudioCommand::LoadFile(uri) => {
                    let _ = pipeline.set_state(gst::State::Ready);
                    pipeline.set_property("uri", &uri);
                    let _ = pipeline.set_state(gst::State::Playing);
                }
                AudioCommand::Play => {
                    let _ = pipeline.set_state(gst::State::Playing);
                }
                AudioCommand::Pause => {
                    let _ = pipeline.set_state(gst::State::Paused);
                }
                AudioCommand::Stop => {
                    let _ = pipeline.set_state(gst::State::Null);
                    current_state = PlayerState::Stopped;
                    let _ = event_tx.send(AudioStatus::StateChanged(current_state.clone()));
                }
                AudioCommand::SetVolume(v) => {
                    pipeline.set_property("volume", v);
                }
                // כאן טיפול באקולייזר
                AudioCommand::SetEq(band_idx, gain) => {
                    let prop_name = format!("band{}", band_idx);

                    // --- התיקון: הגבלת הטווח (Clamping) ---
                    // GStreamer 10-bands תומך מקסימום ב-12dB
                    let safe_gain = gain.clamp(-24.0, 12.0);

                    // הדפסה לטרמינל כדי שתראה שזה עובד
                    println!(
                        "🎚 EQ {}: {:.1} dB (Clamped from {:.1})",
                        prop_name, safe_gain, gain
                    );

                    equalizer.set_property(&prop_name, safe_gain);
                }
                AudioCommand::Seek(percent) => {
                    if let Some(dur) = pipeline.query_duration::<gst::ClockTime>() {
                        let target_ns = (dur.nseconds() as f64 * (percent as f64 / 100.0)) as u64;
                        let _ = pipeline.seek_simple(
                            gst::SeekFlags::FLUSH | gst::SeekFlags::KEY_UNIT,
                            gst::ClockTime::from_nseconds(target_ns),
                        );
                    }
                }
                AudioCommand::Shutdown => {
                    let _ = pipeline.set_state(gst::State::Null);
                    return;
                }
            }
        }

        // --- טיפול בהודעות מהמנוע (GStreamer Bus) ---
        if let Some(msg) = bus.timed_pop(gst::ClockTime::from_mseconds(30)) {
            use gst::MessageView;
            match msg.view() {
                MessageView::Eos(..) => {
                    let _ = pipeline.set_state(gst::State::Ready);
                    current_state = PlayerState::Stopped;
                    let _ = event_tx.send(AudioStatus::EndOfStream);

                }

                MessageView::DurationChanged(..) => {
                    if let Some(dur) = pipeline.query_duration::<gst::ClockTime>() {
                        let _ = event_tx.send(AudioStatus::DurationUpdated(dur.seconds() as f64));
                    }
                }
                MessageView::StateChanged(s) => {
                    if s.src()
                        .map(|src| src == pipeline.upcast_ref::<gst::Object>())
                        .unwrap_or(false)
                    {
                        let new_state = match s.current() {
                            gst::State::Playing => PlayerState::Playing,
                            gst::State::Paused => PlayerState::Paused,
                            _ => PlayerState::Stopped,
                        };
                        if new_state != current_state {
                            current_state = new_state.clone();
                            let _ = event_tx.send(AudioStatus::StateChanged(current_state.clone()));
                        }
                    }
                }
                _ => {}
            }
        }

        // --- עדכון מיקום (Progress Bar) ---
        // זה החלק שהיה חסר לך או לא עבד בגלל הבלגן בסטייט
        if current_state == PlayerState::Playing && last_update.elapsed().as_millis() > 100 {
            if let Some(pos) = pipeline.query_position::<gst::ClockTime>() {
                let _ = event_tx.send(AudioStatus::PositionUpdated(pos.seconds() as f64));
                last_update = std::time::Instant::now();

            }

            // בונוס: וידוא שה-Duration מעודכן
            if let Some(dur) = pipeline.query_duration::<gst::ClockTime>() {
                let _ = event_tx.send(AudioStatus::DurationUpdated(dur.seconds() as f64));
            }
        }
    }
}
