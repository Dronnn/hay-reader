#include "../../Bridge/Bridging.h"

// Keep C++ runtime exceptions inside the native boundary.
piper_synthesizer *speaker_create(const char *model, const char *config, const char *data) {
    try { return piper_create(model, config, data); }
    catch (...) { return nullptr; }
}
int speaker_start(piper_synthesizer *synth, const char *text, const piper_synthesize_options *options) {
    try { return piper_synthesize_start(synth, text, options); }
    catch (...) { return PIPER_ERR_GENERIC; }
}
int speaker_next(piper_synthesizer *synth, piper_audio_chunk *chunk) {
    try { return piper_synthesize_next(synth, chunk); }
    catch (...) { return PIPER_ERR_GENERIC; }
}
