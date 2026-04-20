/* gfx_sound.h — minimal single-voice WAV playback for RGC-BASIC.
 *
 * Backs the BASIC-level LOADSOUND / PLAYSOUND / STOPSOUND /
 * UNLOADSOUND / SOUNDPLAYING verbs. Available in basic-gfx (native
 * Raylib) and basic-wasm-raylib — compiled out of non-GFX_VIDEO
 * builds and the frozen canvas WASM target.
 *
 * Single voice v1: PLAYSOUND on a second slot stops whichever was
 * already playing. No pause/resume/volume/loop yet (tracked in
 * to-do.md under Sound MVP). */
#ifndef GFX_SOUND_H
#define GFX_SOUND_H

#define GFX_SOUND_MAX_SLOTS 32

/* Init is idempotent; call once before any other gfx_sound_* fn.
 * Closes the audio device at process teardown. */
void gfx_sound_init(void);
void gfx_sound_shutdown(void);

/* Resolve paths relative to the BASIC program file, matching the
 * sprite convention. Set once by the interpreter; empty means
 * treat paths as cwd-relative. */
void gfx_sound_set_base_dir(const char *dir);

/* Load / free a WAV into slot. Returns 0 on success, -1 on error
 * (missing file, unsupported format, out-of-range slot). Slots are
 * 0-based [0, GFX_SOUND_MAX_SLOTS). Loading onto a populated slot
 * replaces the previous sound; unloading a playing slot stops it. */
int  gfx_sound_load(int slot, const char *path);
void gfx_sound_unload(int slot);

/* Play or stop. Single-voice rule: gfx_sound_play stops any other
 * voice first. gfx_sound_stop halts the active voice (no-op if
 * nothing playing). Returns 0 on success, -1 if slot is empty. */
int  gfx_sound_play(int slot);
void gfx_sound_stop(void);

/* Non-zero while the current voice is audible; 0 when idle. */
int  gfx_sound_is_playing(void);

/* ---------------------------------------------------------------
 * Music streams — tracker modules (MOD / XM / S3M / IT) and long-
 * form OGG / MP3 loops. Separate slot pool from one-shot WAVs
 * because raylib's Music type is a streaming decoder with its own
 * UpdateMusicStream pump, not a preloaded Sound buffer.
 *
 * The renderer calls gfx_music_tick() every frame to keep the
 * streams fed — without it raudio underflows and the track stops
 * within a second. All other entry points are interpreter-thread
 * safe (same miniaudio guarantees that WAV uses).
 * --------------------------------------------------------------- */
#define GFX_MUSIC_MAX_SLOTS 8

int  gfx_music_load(int slot, const char *path);
void gfx_music_unload(int slot);
int  gfx_music_play(int slot);
void gfx_music_stop(int slot);
void gfx_music_pause(int slot);
void gfx_music_resume(int slot);
int  gfx_music_is_playing(int slot);
void gfx_music_set_volume(int slot, float vol);   /* 0.0 .. 1.0 */
void gfx_music_set_loop(int slot, int loop);      /* 0 = one-shot, 1 = loop */

/* Advance decoding for every loaded Music stream. Cheap enough to
 * call each render frame; a missed tick just shortens the next
 * audible window. */
void gfx_music_tick(void);

#endif /* GFX_SOUND_H */
