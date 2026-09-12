#include "piper.h"
#ifdef __cplusplus
extern "C" {
#endif
piper_synthesizer *speaker_create(const char *, const char *, const char *);
int speaker_start(piper_synthesizer *, const char *, const piper_synthesize_options *);
int speaker_next(piper_synthesizer *, piper_audio_chunk *);
#ifdef __cplusplus
}
#endif

#include "../../native/TranslationBridge.h"
