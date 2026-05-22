# TODO

## LexBuild

- **Homograph detection**: words that share the same spelling but differ in meaning/POS (e.g. "Bank" noun vs verb).
  Planned check via dwds engine. Current behaviour: all forms are written as-is; a separate validation service will detect and resolve homographs post-import.

- **Улучшение покрытия слов** (TASK-11 follow-up): разработать и дополнить стратегию покрытия переводов. Варианты: (1) синтетические переводы DE→EN→RU с пометкой `quality='synthetic'`; (2) импорт дампа dict.cc (DE↔RU, ~600k пар); (3) пользовательская верификация в интерфейсе. Цель — coverage ≥ 80%.

- **Form quality upgrade** (TASK-11 follow-up): words with `word_forms.quality='generated'` should be re-checked against a newer de-extract dump after initial import. When a generated form is found in the dictionary, upgrade quality to `matches` or `dictionary`. Design a background job or CLI command for this upgrade pass.
