/* gfx_sound.c — raylib-backed single-voice sound for RGC-BASIC.
 *
 * Only compiled when the parent target defines GFX_VIDEO and is
 * linking against raylib (native basic-gfx or basic-wasm-raylib).
 * Terminal + frozen canvas WASM targets omit this file.
 *
 * Threading: raylib's miniaudio backend is internally thread-safe
 * for Play/Stop/IsPlaying, and LoadSound does file I/O + alloc with
 * no GL dependency. All entry points therefore run directly from
 * the interpreter thread — no command queue needed. */

#include "gfx_sound.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "raylib.h"

static int  g_inited = 0;
static Sound g_sounds[GFX_SOUND_MAX_SLOTS];
static int  g_loaded[GFX_SOUND_MAX_SLOTS];
static int  g_active_slot = -1;
static char g_base_dir[1024];

#ifndef GFX_SOUND_PATH_MAX
#define GFX_SOUND_PATH_MAX 1024
#endif

static void resolve_path(char *out, size_t outsz, const char *rel)
{
    if (!rel || !rel[0]) { out[0] = '\0'; return; }
    if (rel[0] == '/' || (rel[0] != '\0' && rel[1] == ':' &&
                          ((rel[0] >= 'A' && rel[0] <= 'Z') ||
                           (rel[0] >= 'a' && rel[0] <= 'z')))) {
        snprintf(out, outsz, "%s", rel);
        return;
    }
    if (g_base_dir[0] != '\0') {
        snprintf(out, outsz, "%s/%s", g_base_dir, rel);
    } else {
        snprintf(out, outsz, "%s", rel);
    }
}

void gfx_sound_set_base_dir(const char *dir)
{
    if (!dir || !dir[0]) {
        g_base_dir[0] = '\0';
        return;
    }
    strncpy(g_base_dir, dir, sizeof(g_base_dir) - 1);
    g_base_dir[sizeof(g_base_dir) - 1] = '\0';
}

void gfx_sound_init(void)
{
    if (g_inited) return;
    InitAudioDevice();
    memset(g_loaded, 0, sizeof(g_loaded));
    g_active_slot = -1;
    g_inited = 1;
}

void gfx_sound_shutdown(void)
{
    int i;
    if (!g_inited) return;
    for (i = 0; i < GFX_SOUND_MAX_SLOTS; i++) {
        if (g_loaded[i]) {
            UnloadSound(g_sounds[i]);
            g_loaded[i] = 0;
        }
    }
    CloseAudioDevice();
    g_active_slot = -1;
    g_inited = 0;
}

int gfx_sound_load(int slot, const char *path)
{
    char full[GFX_SOUND_PATH_MAX];
    Sound s;
    if (slot < 0 || slot >= GFX_SOUND_MAX_SLOTS) return -1;
    if (!path || !path[0]) return -1;
    gfx_sound_init();
    resolve_path(full, sizeof(full), path);
    /* Replace any existing sound in this slot (stops it first if playing). */
    if (g_loaded[slot]) {
        if (g_active_slot == slot) { StopSound(g_sounds[slot]); g_active_slot = -1; }
        UnloadSound(g_sounds[slot]);
        g_loaded[slot] = 0;
    }
    s = LoadSound(full);
    if (s.stream.buffer == NULL) return -1;
    g_sounds[slot] = s;
    g_loaded[slot] = 1;
    return 0;
}

void gfx_sound_unload(int slot)
{
    if (slot < 0 || slot >= GFX_SOUND_MAX_SLOTS) return;
    if (!g_loaded[slot]) return;
    if (g_active_slot == slot) {
        StopSound(g_sounds[slot]);
        g_active_slot = -1;
    }
    UnloadSound(g_sounds[slot]);
    g_loaded[slot] = 0;
}

int gfx_sound_play(int slot)
{
    if (!g_inited) gfx_sound_init();
    if (slot < 0 || slot >= GFX_SOUND_MAX_SLOTS) return -1;
    if (!g_loaded[slot]) return -1;
    /* Single voice: stop whatever was playing before starting this slot.
     * Raylib's PlaySound restarts from the beginning if called twice on
     * the same slot — matches the "restart on PLAYSOUND" spec. */
    if (g_active_slot >= 0 && g_active_slot != slot && g_loaded[g_active_slot]) {
        StopSound(g_sounds[g_active_slot]);
    }
    PlaySound(g_sounds[slot]);
    g_active_slot = slot;
    return 0;
}

void gfx_sound_stop(void)
{
    if (!g_inited) return;
    if (g_active_slot >= 0 && g_active_slot < GFX_SOUND_MAX_SLOTS &&
        g_loaded[g_active_slot]) {
        StopSound(g_sounds[g_active_slot]);
    }
    g_active_slot = -1;
}

int gfx_sound_is_playing(void)
{
    if (!g_inited) return 0;
    if (g_active_slot < 0 || g_active_slot >= GFX_SOUND_MAX_SLOTS) return 0;
    if (!g_loaded[g_active_slot]) return 0;
    if (IsSoundPlaying(g_sounds[g_active_slot])) return 1;
    /* Natural end-of-sample: clear the active pointer so SOUNDPLAYING()
     * stabilises at 0 without requiring STOPSOUND from the program. */
    g_active_slot = -1;
    return 0;
}

/* --------------------------------------------------------------
 * Music streams. Separate slot pool from one-shot WAV above.
 * -------------------------------------------------------------- */

static Music g_music[GFX_MUSIC_MAX_SLOTS];
static int   g_music_loaded[GFX_MUSIC_MAX_SLOTS];

int gfx_music_load(int slot, const char *path)
{
    char full[GFX_SOUND_PATH_MAX];
    Music m;
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return -1;
    if (!path || !path[0]) return -1;
    gfx_sound_init();
    resolve_path(full, sizeof(full), path);
    if (g_music_loaded[slot]) {
        StopMusicStream(g_music[slot]);
        UnloadMusicStream(g_music[slot]);
        g_music_loaded[slot] = 0;
    }
    m = LoadMusicStream(full);
    /* raylib returns Music with a NULL ctxData/stream.buffer when
     * the file couldn't be decoded. Trust the stream.buffer check
     * that matches the pattern gfx_sound_load uses. */
    if (m.stream.buffer == NULL) return -1;
    g_music[slot] = m;
    g_music_loaded[slot] = 1;
    return 0;
}

void gfx_music_unload(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    StopMusicStream(g_music[slot]);
    UnloadMusicStream(g_music[slot]);
    g_music_loaded[slot] = 0;
}

int gfx_music_play(int slot)
{
    if (!g_inited) gfx_sound_init();
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return -1;
    if (!g_music_loaded[slot]) return -1;
    PlayMusicStream(g_music[slot]);
    return 0;
}

void gfx_music_stop(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    StopMusicStream(g_music[slot]);
}

void gfx_music_pause(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    PauseMusicStream(g_music[slot]);
}

void gfx_music_resume(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    ResumeMusicStream(g_music[slot]);
}

int gfx_music_is_playing(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0;
    if (!g_music_loaded[slot]) return 0;
    return IsMusicStreamPlaying(g_music[slot]) ? 1 : 0;
}

void gfx_music_set_volume(int slot, float vol)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    if (vol < 0.0f) vol = 0.0f;
    if (vol > 1.0f) vol = 1.0f;
    SetMusicVolume(g_music[slot], vol);
}

void gfx_music_set_loop(int slot, int loop)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    g_music[slot].looping = loop ? true : false;
}

void gfx_music_tick(void)
{
    int i;
    if (!g_inited) return;
    for (i = 0; i < GFX_MUSIC_MAX_SLOTS; i++) {
        if (g_music_loaded[i]) {
            UpdateMusicStream(g_music[i]);
        }
    }
}
