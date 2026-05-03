#include "eri_toml.h"

#include <exception>
#include <iterator>
#include <string>
#include <string_view>

#include "toml.hpp"

struct EriTomlError {
    std::string message;
    size_t line;
    size_t column;
};

namespace {

const toml::node* as_node(const EriTomlNode* n) {
    return reinterpret_cast<const toml::node*>(n);
}

const EriTomlNode* to_handle(const toml::node* n) {
    return reinterpret_cast<const EriTomlNode*>(n);
}

}  // namespace

extern "C" {

EriTomlNode* eri_toml_parse(const char* utf8, size_t len, EriTomlError** err_out) {
    if (err_out) *err_out = nullptr;
    try {
        auto* tbl = new toml::table(toml::parse(std::string_view{utf8, len}));
        return reinterpret_cast<EriTomlNode*>(static_cast<toml::node*>(tbl));
    } catch (const toml::parse_error& e) {
        if (err_out) {
            auto* err = new EriTomlError{
                std::string(e.description()),
                static_cast<size_t>(e.source().begin.line),
                static_cast<size_t>(e.source().begin.column),
            };
            *err_out = err;
        }
        return nullptr;
    } catch (const std::exception& e) {
        if (err_out) {
            *err_out = new EriTomlError{std::string(e.what()), 0, 0};
        }
        return nullptr;
    } catch (...) {
        if (err_out) {
            *err_out = new EriTomlError{std::string("unknown parse error"), 0, 0};
        }
        return nullptr;
    }
}

void eri_toml_node_free(EriTomlNode* root) {
    // Root is always a heap-allocated toml::table; node has a virtual destructor.
    delete reinterpret_cast<toml::node*>(root);
}

const char* eri_toml_error_message(const EriTomlError* err) {
    return err ? err->message.c_str() : nullptr;
}

size_t eri_toml_error_line(const EriTomlError* err) {
    return err ? err->line : 0;
}

size_t eri_toml_error_column(const EriTomlError* err) {
    return err ? err->column : 0;
}

void eri_toml_error_free(EriTomlError* err) {
    delete err;
}

bool eri_toml_is_table(const EriTomlNode* node) {
    auto* n = as_node(node);
    return n != nullptr && n->is_table();
}

bool eri_toml_is_array(const EriTomlNode* node) {
    auto* n = as_node(node);
    return n != nullptr && n->is_array();
}

bool eri_toml_is_string(const EriTomlNode* node) {
    auto* n = as_node(node);
    return n != nullptr && n->is_string();
}

const EriTomlNode* eri_toml_table_get(const EriTomlNode* node, const char* key) {
    auto* n = as_node(node);
    if (!n) return nullptr;
    auto* tbl = n->as_table();
    if (!tbl) return nullptr;
    auto it = tbl->find(std::string_view{key});
    if (it == tbl->end()) return nullptr;
    return to_handle(&it->second);
}

size_t eri_toml_table_size(const EriTomlNode* node) {
    auto* n = as_node(node);
    if (!n) return 0;
    auto* tbl = n->as_table();
    return tbl ? tbl->size() : 0;
}

const char* eri_toml_table_key_at(const EriTomlNode* node, size_t i, size_t* out_len) {
    if (out_len) *out_len = 0;
    auto* n = as_node(node);
    if (!n) return nullptr;
    auto* tbl = n->as_table();
    if (!tbl || i >= tbl->size()) return nullptr;
    auto it = tbl->cbegin();
    std::advance(it, static_cast<std::ptrdiff_t>(i));
    auto sv = it->first.str();
    if (out_len) *out_len = sv.size();
    return sv.data();
}

const EriTomlNode* eri_toml_table_value_at(const EriTomlNode* node, size_t i) {
    auto* n = as_node(node);
    if (!n) return nullptr;
    auto* tbl = n->as_table();
    if (!tbl || i >= tbl->size()) return nullptr;
    auto it = tbl->cbegin();
    std::advance(it, static_cast<std::ptrdiff_t>(i));
    return to_handle(&it->second);
}

size_t eri_toml_array_size(const EriTomlNode* node) {
    auto* n = as_node(node);
    if (!n) return 0;
    auto* arr = n->as_array();
    return arr ? arr->size() : 0;
}

const EriTomlNode* eri_toml_array_at(const EriTomlNode* node, size_t i) {
    auto* n = as_node(node);
    if (!n) return nullptr;
    auto* arr = n->as_array();
    if (!arr || i >= arr->size()) return nullptr;
    return to_handle(arr->get(i));
}

bool eri_toml_as_string(const EriTomlNode* node, const char** out_ptr, size_t* out_len) {
    auto* n = as_node(node);
    if (!n) return false;
    auto* s = n->as_string();
    if (!s) return false;
    const std::string& str = s->get();
    if (out_ptr) *out_ptr = str.data();
    if (out_len) *out_len = str.size();
    return true;
}

}  // extern "C"
