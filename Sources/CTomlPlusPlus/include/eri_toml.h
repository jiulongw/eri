#ifndef ERI_TOML_H
#define ERI_TOML_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EriTomlNode  EriTomlNode;
typedef struct EriTomlError EriTomlError;

EriTomlNode* eri_toml_parse(const char* utf8, size_t len, EriTomlError** err_out);
void         eri_toml_node_free(EriTomlNode* root);

const char* eri_toml_error_message(const EriTomlError* err);
size_t      eri_toml_error_line(const EriTomlError* err);
size_t      eri_toml_error_column(const EriTomlError* err);
void        eri_toml_error_free(EriTomlError* err);

bool eri_toml_is_table (const EriTomlNode* node);
bool eri_toml_is_array (const EriTomlNode* node);
bool eri_toml_is_string(const EriTomlNode* node);

const EriTomlNode* eri_toml_table_get      (const EriTomlNode* node, const char* key);
size_t             eri_toml_table_size     (const EriTomlNode* node);
const char*        eri_toml_table_key_at   (const EriTomlNode* node, size_t i, size_t* out_len);
const EriTomlNode* eri_toml_table_value_at (const EriTomlNode* node, size_t i);

size_t             eri_toml_array_size(const EriTomlNode* node);
const EriTomlNode* eri_toml_array_at  (const EriTomlNode* node, size_t i);

bool eri_toml_as_string(const EriTomlNode* node, const char** out_ptr, size_t* out_len);

#ifdef __cplusplus
}
#endif

#endif
