use std::ffi::CStr;
use std::os::raw::{c_char, c_double, c_float};
use mpris_server::{Property, Player, PlayerInterface, RootInterface};

// אומרים ל-Rust להשתמש במנוע שכתבת
mod audio_engine;
use audio_engine::AudioEngine;

// ==========================================
// 1. ניהול מחזור החיים של המנוע
// ==========================================

#[unsafe(no_mangle)]
pub extern "C" fn engine_new() -> *mut AudioEngine {
    // יוצרים את המנוע ומעבירים אותו לזיכרון ש-Rust לא ימחק אוטומטית (Box)
    let engine = AudioEngine::new_headless();
    Box::into_raw(Box::new(engine))
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_free(ptr: *mut AudioEngine) {
    if !ptr.is_null() {
        // מחזירים ל-Rust את השליטה על הזיכרון כדי שינקה אותו
        unsafe {
            let _ = Box::from_raw(ptr);
        }
    }
}

// ==========================================
// 2. פקודות שליטה (Play, Pause, Load)
// ==========================================

#[unsafe(no_mangle)]
pub extern "C" fn engine_load(ptr: *mut AudioEngine, path: *const c_char) {
    if ptr.is_null() || path.is_null() {
        return;
    }
    let engine = unsafe { &mut *ptr };
    let c_str = unsafe { CStr::from_ptr(path) };

    if let Ok(path_str) = c_str.to_str() {
        engine.load(path_str);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_play(ptr: *mut AudioEngine) {
    if ptr.is_null() {
        return;
    }
    let engine = unsafe { &mut *ptr };
    engine.play();
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_pause(ptr: *mut AudioEngine) {
    if ptr.is_null() {
        return;
    }
    let engine = unsafe { &mut *ptr };
    engine.pause();
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_set_volume(ptr: *mut AudioEngine, vol: c_float) {
    if ptr.is_null() {
        return;
    }
    let engine = unsafe { &mut *ptr };
    engine.set_volume(vol);
}

// ==========================================
// 3. עדכון וקריאת נתונים (לשימוש ה-UI)
// ==========================================

// פונקציה ש-Dart תקרא לה בלולאה כדי לעדכן את הסטטוסים מה-Thread של GStreamer
#[unsafe(no_mangle)]
pub extern "C" fn engine_update(ptr: *mut AudioEngine) -> bool {
    if ptr.is_null() {
        return false;
    }
    let engine = unsafe { &mut *ptr };
    engine.update()
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_get_position(ptr: *mut AudioEngine) -> c_double {
    if ptr.is_null() {
        return 0.0;
    }
    let engine = unsafe { &mut *ptr };
    engine.current_position
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_get_duration(ptr: *mut AudioEngine) -> c_double {
    if ptr.is_null() {
        return 0.0;
    }
    let engine = unsafe { &mut *ptr };
    engine.current_duration
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_set_eq(ptr: *mut AudioEngine, band_idx: usize, gain: c_double) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *ptr };
    engine.set_eq(band_idx, gain);
}

#[unsafe(no_mangle)]
pub extern "C" fn engine_seek(ptr: *mut AudioEngine, percent: c_float) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *ptr };
    engine.seek(percent);
}



#[unsafe(no_mangle)]
pub extern "C" fn engine_update_mpris_metadata(
    ptr: *mut AudioEngine,
    title: *const c_char,
    artist: *const c_char,
) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *ptr };

    let title_str = unsafe { std::ffi::CStr::from_ptr(title).to_string_lossy().into_owned() };
    let artist_str = unsafe { std::ffi::CStr::from_ptr(artist).to_string_lossy().into_owned() };

    // כאן נעדכן את ה-MPRIS Server (בהנחה שהגדרת אותו ב-struct)
    // הערה: בגרסה פשוטה, GStreamer יודע לפעמים לעשות חלק מזה לבד,
    // אבל אנחנו רוצים שליטה מלאה.
    println!("MPRIS Update: {} by {}", title_str, artist_str);
}
