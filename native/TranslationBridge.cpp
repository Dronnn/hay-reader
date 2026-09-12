#include "TranslationBridge.h"
#include <ctranslate2/translator.h>
#include <sentencepiece_processor.h>
#include <memory>
#include <cstring>
#include <cstdlib>
#include <stdexcept>
#include <filesystem>

struct TranslationEngine {
    ctranslate2::Translator translator;
    sentencepiece::SentencePieceProcessor tokenizer;
    sentencepiece::SentencePieceProcessor outputTokenizer;
    bool bilingual;
    explicit TranslationEngine(const std::string &directory)
        : translator(directory, ctranslate2::Device::CPU, ctranslate2::ComputeType::INT8),
          bilingual(std::filesystem::exists(directory + "/source.spm")) {
        if (!tokenizer.Load(directory + (bilingual ? "/source.spm" : "/sentencepiece.bpe.model")).ok() ||
            !outputTokenizer.Load(directory + (bilingual ? "/target.spm" : "/sentencepiece.bpe.model")).ok())
            throw std::runtime_error("Tokenizer unavailable");
    }
};
void *translation_create(const char *directory) {
    try { return new TranslationEngine(directory); } catch (...) { return nullptr; }
}
void translation_destroy(void *handle) { delete static_cast<TranslationEngine *>(handle); }
char *translation_run(void *handle, const char *text, const char *targetLanguage, int *error) {
    *error = 2;
    try {
        if (!handle || !text) return nullptr;
        auto &engine = *static_cast<TranslationEngine *>(handle);
        std::vector<std::string> tokens;
        if (!engine.tokenizer.Encode(text, &tokens).ok() || tokens.empty()) return nullptr;
        if (tokens.size() > 450) { *error = 1; return nullptr; }
        if (!engine.bilingual) tokens.insert(tokens.begin(), std::string("__") + targetLanguage + "__");
        tokens.emplace_back("</s>");
        ctranslate2::TranslationOptions options;
        options.beam_size = 5;
        options.max_input_length = 512;
        options.max_decoding_length = std::min<size_t>(512, tokens.size() * 3 + 32);
        options.no_repeat_ngram_size = 3;
        auto results = engine.translator.translate_batch({tokens}, options);
        if (results.empty() || results.front().hypotheses.empty()) return nullptr;
        if (results.front().hypotheses.front().size() >= options.max_decoding_length) return nullptr;
        std::string output;
        if (!engine.outputTokenizer.Decode(results.front().hypotheses.front(), &output).ok() || output.empty()) return nullptr;
        *error = 0;
        return strdup(output.c_str());
    } catch (...) { return nullptr; }
}
void translation_free_text(char *text) { free(text); }
