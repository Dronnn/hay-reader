#pragma once
#ifdef __cplusplus
extern "C" {
#endif
void *translation_create(const char *directory);
void translation_destroy(void *handle);
char *translation_run(void *handle, const char *text, const char *targetLanguage, int *error);
void translation_free_text(char *text);
#ifdef __cplusplus
}
#endif
