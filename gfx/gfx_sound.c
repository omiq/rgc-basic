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

/* Forward decls for the master-mix peak tap (defined below with
 * the Music API). Lives up here because gfx_sound_init attaches
 * the processor on first init, before the Music section. */
static float g_peak_recent;
static float g_peak_hold;
static int   g_peak_attached;
static void  peak_mix_processor(void *buf, unsigned int frames);

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
    if (!g_peak_attached) {
        AttachAudioMixedProcessor(peak_mix_processor);
        g_peak_attached = 1;
    }
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
    if (g_peak_attached) {
        DetachAudioMixedProcessor(peak_mix_processor);
        g_peak_attached = 0;
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

static Music  g_music[GFX_MUSIC_MAX_SLOTS];
static int    g_music_loaded[GFX_MUSIC_MAX_SLOTS];
static double g_music_length[GFX_MUSIC_MAX_SLOTS]; /* seconds, 0 if unknown */

/* MOD-only metadata. All zeroed / empty-string for non-MOD formats.
 * Populated at LOADMUSIC time from the MOD header. Fixed upper
 * bound of 31 samples matches the classic Protracker / FastTracker
 * layout — 15-sample "Soundtracker" MODs are rare enough to ignore
 * here (we only honour the 31-sample layout for metadata). */
struct mod_meta {
    int  is_mod;
    int  channels;
    int  n_samples;       /* always 31 if is_mod, but kept for future 15-sample support */
    int  n_patterns;      /* max(order[]) + 1 */
    int  order_count;     /* song length, 1..128 */
    char title[21];       /* 20 bytes + NUL */
    char sample_name[31][23]; /* 22 bytes + NUL */
};
static struct mod_meta g_mod_meta[GFX_MUSIC_MAX_SLOTS];

/* Master-mix peak meter. raylib's AttachAudioMixedProcessor invokes
 * the callback once per mix chunk with the final float PCM output.
 * We scan for peak |sample|, stash the latest and a slow-decay hold
 * value for VU visualisation. No per-slot peak because the API has
 * no userdata; the demo plays one track at a time anyway. Storage
 * is at the top of the file so gfx_sound_init can reference it. */

static void peak_mix_processor(void *buf, unsigned int frames)
{
    float *samples = (float *)buf;
    unsigned int n = frames * 2; /* raudio mix is stereo interleaved */
    float peak = 0.0f;
    unsigned int i;
    for (i = 0; i < n; i++) {
        float a = samples[i];
        if (a < 0.0f) a = -a;
        if (a > peak) peak = a;
    }
    g_peak_recent = peak;
    if (peak > g_peak_hold) g_peak_hold = peak;
    else g_peak_hold *= 0.92f; /* ~ -0.7 dB per mix chunk */
}

/* --------------------------------------------------------------
 * MOD length computation.
 *
 * Walks the pattern order table honouring Fxx (speed/BPM), Bxx
 * (order jump), Dxx (pattern break), E6x (pattern loop). Bounded
 * by a 2-visit cap per order entry to avoid infinite loops. Runs
 * in microseconds — O(orders * 64 rows * channels).
 * -------------------------------------------------------------- */

static int mod_num_channels(const unsigned char *tag)
{
    if (!memcmp(tag, "M.K.", 4) || !memcmp(tag, "M!K!", 4) ||
        !memcmp(tag, "FLT4", 4) || !memcmp(tag, "4CHN", 4)) return 4;
    if (!memcmp(tag, "6CHN", 4)) return 6;
    if (!memcmp(tag, "8CHN", 4) || !memcmp(tag, "FLT8", 4) ||
        !memcmp(tag, "OCTA", 4) || !memcmp(tag, "CD81", 4)) return 8;
    if (tag[1] == 'C' && tag[2] == 'H' && tag[3] == 'N' &&
        tag[0] >= '0' && tag[0] <= '9') return tag[0] - '0';
    if (tag[2] == 'C' && tag[3] == 'H' &&
        tag[0] >= '0' && tag[0] <= '9' && tag[1] >= '0' && tag[1] <= '9')
        return (tag[0] - '0') * 10 + (tag[1] - '0');
    return 0;
}

static double compute_mod_length(const char *path)
{
    FILE *f;
    long size;
    unsigned char *buf;
    const unsigned char *order, *patterns;
    int channels, song_len, npatterns;
    int speed = 6, bpm = 125;
    int order_idx = 0, row = 0;
    int loop_start_row = 0, loop_count = 0;
    long pat_bytes;
    long row_budget = 200000;
    double total = 0.0;
    unsigned char ord_visit[128];
    size_t got;
    int i, max_pat = 0;

    f = fopen(path, "rb");
    if (!f) return 0.0;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return 0.0; }
    size = ftell(f);
    if (size < 1084 || size > (long)(32 * 1024 * 1024)) { fclose(f); return 0.0; }
    fseek(f, 0, SEEK_SET);
    buf = (unsigned char *)malloc((size_t)size);
    if (!buf) { fclose(f); return 0.0; }
    got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(buf); return 0.0; }

    channels = mod_num_channels(buf + 1080);
    if (channels <= 0 || channels > 32) { free(buf); return 0.0; }
    song_len = buf[950];
    if (song_len < 1 || song_len > 128) { free(buf); return 0.0; }
    order = buf + 952;
    for (i = 0; i < 128; i++) if (order[i] > max_pat) max_pat = order[i];
    npatterns = max_pat + 1;
    pat_bytes = 64L * channels * 4;
    if (1084 + (long)npatterns * pat_bytes > size) { free(buf); return 0.0; }
    patterns = buf + 1084;
    memset(ord_visit, 0, sizeof(ord_visit));

    while (order_idx < song_len && row_budget > 0) {
        int pat;
        const unsigned char *prows;
        int next_order = order_idx + 1;
        int next_row = 0;
        if (++ord_visit[order_idx] > 2) break;
        pat = order[order_idx];
        if (pat >= npatterns) break;
        prows = patterns + (long)pat * pat_bytes;
        for (; row < 64 && row_budget > 0; row++, row_budget--) {
            int ch, broke = 0;
            for (ch = 0; ch < channels; ch++) {
                const unsigned char *cell = prows + ((long)row * channels + ch) * 4;
                int eff = cell[2] & 0x0F;
                int param = cell[3];
                if (eff == 0xF) {
                    if (param == 0) { /* ignored */ }
                    else if (param < 0x20) speed = param;
                    else bpm = param;
                } else if (eff == 0xB) {
                    next_order = param;
                    next_row = 0;
                    broke = 1;
                } else if (eff == 0xD) {
                    next_row = ((param >> 4) * 10) + (param & 0x0F);
                    if (next_row > 63) next_row = 0;
                    /* only set if Bxx didn't already redirect */
                    if (!broke) next_order = order_idx + 1;
                    broke = 1;
                } else if (eff == 0xE && (param >> 4) == 0x6) {
                    int x = param & 0x0F;
                    if (x == 0) loop_start_row = row;
                    else if (loop_count < x) {
                        loop_count++;
                        next_order = order_idx;
                        next_row = loop_start_row;
                        broke = 1;
                    } else {
                        loop_count = 0;
                    }
                }
            }
            if (bpm < 32) bpm = 32;
            total += (double)speed * 2.5 / (double)bpm;
            if (broke) break;
        }
        order_idx = next_order;
        row = next_row;
    }
    free(buf);
    return total;
}

/* Copy N bytes from a MOD header field into `out`, trim trailing
 * space / NUL / 0xFF padding, replace non-printable bytes with
 * spaces so weird tracker outputs don't show control characters.
 * Ensures `out` is NUL-terminated. */
static void mod_field_copy(char *out, int buflen, const unsigned char *src, int n)
{
    int i, end;
    if (buflen <= 0) return;
    if (n > buflen - 1) n = buflen - 1;
    for (i = 0; i < n; i++) {
        unsigned char c = src[i];
        if (c == 0 || c == 0xFF) { out[i] = ' '; }
        else if (c < 0x20 || c == 0x7F) { out[i] = ' '; }
        else { out[i] = (char)c; }
    }
    out[n] = '\0';
    end = n;
    while (end > 0 && out[end - 1] == ' ') end--;
    out[end] = '\0';
}

/* Fill g_mod_meta[slot] from the MOD file at `path`. Called only
 * when path_looks_like_mod() returned 1. Leaves the slot zeroed on
 * I/O failure — callers then see channels=0 / empty strings, same
 * fallback as non-MOD formats. */
static void parse_mod_meta(int slot, const char *path)
{
    FILE *f;
    unsigned char hdr[1084];
    struct mod_meta *m;
    int i;
    size_t got;

    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    m = &g_mod_meta[slot];
    memset(m, 0, sizeof(*m));
    f = fopen(path, "rb");
    if (!f) return;
    got = fread(hdr, 1, sizeof(hdr), f);
    fclose(f);
    if (got < sizeof(hdr)) return;

    m->channels = mod_num_channels(hdr + 1080);
    if (m->channels <= 0) return;
    m->is_mod = 1;
    m->n_samples = 31;
    /* 20-byte title */
    mod_field_copy(m->title, sizeof(m->title), hdr, 20);
    /* 31 × 30-byte sample records starting at offset 20.
     * Record layout: 22-byte name, 2-byte length, 1-byte finetune,
     * 1-byte volume, 2-byte loop start, 2-byte loop length. */
    for (i = 0; i < 31; i++) {
        mod_field_copy(m->sample_name[i], sizeof(m->sample_name[i]),
                       hdr + 20 + i * 30, 22);
    }
    m->order_count = hdr[950];
    if (m->order_count < 1 || m->order_count > 128) m->order_count = 0;
    {
        int max_pat = 0;
        for (i = 0; i < 128; i++) if (hdr[952 + i] > max_pat) max_pat = hdr[952 + i];
        m->n_patterns = max_pat + 1;
    }
}

/* Detect MOD tag at offset 1080 without reloading the file for
 * large tracks. Returns 1 if buf[1080..1083] matches a known
 * MOD/FastTracker4+ identifier. */
static int path_looks_like_mod(const char *path)
{
    FILE *f = fopen(path, "rb");
    unsigned char tag[4];
    if (!f) return 0;
    if (fseek(f, 1080, SEEK_SET) != 0) { fclose(f); return 0; }
    if (fread(tag, 1, 4, f) != 4) { fclose(f); return 0; }
    fclose(f);
    return mod_num_channels(tag) > 0;
}

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
        g_music_length[slot] = 0.0;
    }
    m = LoadMusicStream(full);
    /* raylib returns Music with a NULL ctxData/stream.buffer when
     * the file couldn't be decoded. Trust the stream.buffer check
     * that matches the pattern gfx_sound_load uses. */
    if (m.stream.buffer == NULL) return -1;
    g_music[slot] = m;
    g_music_loaded[slot] = 1;
    /* Compute track length. MOD: walk pattern/tempo ourselves
     * (jar_mod_max_samples freezes on Windows MinGW — that is why
     * raudio's frameCount was patched to UINT_MAX). Non-MOD: trust
     * raylib's GetMusicTimeLength, which works for formats that
     * store length in the header. */
    if (path_looks_like_mod(full)) {
        g_music_length[slot] = compute_mod_length(full);
        parse_mod_meta(slot, full);
    } else {
        float raylen = GetMusicTimeLength(m);
        g_music_length[slot] = (raylen > 0.0f && raylen < 1.0e8f) ? (double)raylen : 0.0;
        memset(&g_mod_meta[slot], 0, sizeof(g_mod_meta[slot]));
    }
    return 0;
}

void gfx_music_unload(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot]) return;
    StopMusicStream(g_music[slot]);
    UnloadMusicStream(g_music[slot]);
    g_music_loaded[slot] = 0;
    g_music_length[slot] = 0.0;
    memset(&g_mod_meta[slot], 0, sizeof(g_mod_meta[slot]));
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

double gfx_music_length(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0.0;
    if (!g_music_loaded[slot]) return 0.0;
    return g_music_length[slot];
}

double gfx_music_time(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0.0;
    if (!g_music_loaded[slot]) return 0.0;
    return (double)GetMusicTimePlayed(g_music[slot]);
}

float gfx_music_peak(void)
{
    (void)g_peak_recent; /* kept for future "instantaneous" meter */
    return g_peak_hold;
}

/* MOD metadata accessors — all return safe defaults for non-MOD
 * slots (zero integer / empty string). */

void gfx_music_title(int slot, char *out, int buflen)
{
    if (!out || buflen <= 0) return;
    out[0] = '\0';
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot] || !g_mod_meta[slot].is_mod) return;
    snprintf(out, (size_t)buflen, "%s", g_mod_meta[slot].title);
}

void gfx_music_sample_name(int slot, int idx, char *out, int buflen)
{
    if (!out || buflen <= 0) return;
    out[0] = '\0';
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return;
    if (!g_music_loaded[slot] || !g_mod_meta[slot].is_mod) return;
    if (idx < 0 || idx >= g_mod_meta[slot].n_samples) return;
    snprintf(out, (size_t)buflen, "%s", g_mod_meta[slot].sample_name[idx]);
}

int gfx_music_channels(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0;
    if (!g_music_loaded[slot]) return 0;
    return g_mod_meta[slot].channels;
}

int gfx_music_patterns(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0;
    if (!g_music_loaded[slot]) return 0;
    return g_mod_meta[slot].n_patterns;
}

int gfx_music_samples(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0;
    if (!g_music_loaded[slot]) return 0;
    return g_mod_meta[slot].n_samples;
}

int gfx_music_order_count(int slot)
{
    if (slot < 0 || slot >= GFX_MUSIC_MAX_SLOTS) return 0;
    if (!g_music_loaded[slot]) return 0;
    return g_mod_meta[slot].order_count;
}
