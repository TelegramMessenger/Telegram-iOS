#include "LanguageTree.h"

#include "TokenList.h"
#include <boost/regex.hpp>

void LanguageTree::load(const std::string& content)
{
    Buffer buffer{ content };
    parsePatterns(buffer);
    parseGrammars(buffer);
    parseLanguages(buffer);
}

inline uint8_t freadUint8(Buffer &buffer)
{
    uint8_t value = 0;
    if (buffer.offset + sizeof(uint8_t) <= buffer.content.size()) {
        memcpy(&value, &buffer.content[buffer.offset], sizeof(uint8_t));
        buffer.offset += sizeof(uint8_t);
    }
    return value;
}

inline uint16_t freadUint16(Buffer &buffer)
{
    uint16_t value = 0;
    if (buffer.offset + sizeof(uint16_t) <= buffer.content.size()) {
		memcpy(&value, &buffer.content[buffer.offset], sizeof(uint16_t));
        buffer.offset += sizeof(uint16_t);
	}
    return value;
}

inline std::string freadString(Buffer &buffer)
{
    size_t length = freadUint8(buffer);
    if (length >= 254)
    {
        size_t a = freadUint8(buffer);
        size_t b = freadUint8(buffer);
        size_t c = freadUint8(buffer);
        length = a | (b << 8) | (c << 16);
    }

    std::string str(length, '\0');
    if (buffer.offset + length <= buffer.content.size())
	{
		memcpy(&str[0], &buffer.content[buffer.offset], length);
        buffer.offset += length;
	}
    return str;
}

void LanguageTree::parseLanguages(Buffer &buffer)
{
    uint16_t count = freadUint16(buffer);

    for (int i = 0; i < count; ++i)
    {
        std::string name = freadString(buffer);
        std::string displayName = freadString(buffer);
        size_t index = freadUint16(buffer);
        m_languages.emplace(name, std::pair<std::string, size_t>(displayName, index));
    }
}

void LanguageTree::parseGrammars(Buffer &buffer)
{
    uint16_t count = freadUint16(buffer);

    for (int i = 0; i < count; ++i)
    {
        auto grammar = std::make_shared<Grammar>();
        const auto keys = freadUint8(buffer);

        for (int j = 0; j < keys; ++j)
        {
            std::vector<PatternPtr> indices;

            const auto key = freadString(buffer);
            uint8_t ids = freadUint8(buffer);

            for (int k = 0; k < ids; ++k)
            {
                indices.push_back(PatternPtr(shared_from_this(), freadUint16(buffer)));
            }

            grammar->tokens.push_back(GrammarToken(key, indices));
        }

        m_grammars.push_back(grammar);
    }
}

void LanguageTree::parsePatterns(Buffer &buffer)
{
    uint16_t count = freadUint16(buffer);

    for (int i = 0; i < count; ++i)
    {
        std::string item = freadString(buffer);
        std::string_view value(item);
        std::string alias;

        size_t beg = value.find_first_of('/');
        size_t end = value.find_last_of('/');

        if (beg != std::string::npos && end != std::string::npos)
        {
            std::string_view pattern = value.substr(beg + 1, end - (beg + 1));
            std::string_view options = value.substr(end + 1);

            size_t aliasBeg = options.find_first_of(',');
            size_t aliasEnd = options.find_last_of(',');

            std::string alias{ options.substr(aliasBeg + 1, aliasEnd - (aliasBeg + 1)) };
            size_t inside = 0;

            if (aliasEnd + 1 < options.size())
            {
                for (int i = aliasEnd + 1; i < options.size(); i++)
                {
                    char c = options[i];
                    if (c >= '0' && c <= '9')
                    {
                        inside = inside * 10 + (c - '0');
                    }
                    else
                    {
                        assert(false);
                    }
                }
            }
            else
            {
                inside = std::string::npos;
            }

            bool lookbehind = false;
            bool greedy = false;

            boost::regex_constants::syntax_option_type flags
                = boost::regex_constants::ECMAScript | boost::regex_constants::no_mod_m;

            for (char c : options.substr(0, aliasBeg))
            {
                switch (c)
                {
                case 'l':
                    lookbehind = true;
                    break;
                case 'y':
                    greedy = true;
                    break;
                case 'i':
                    flags |= boost::regex_constants::icase;
                    break;
                case 'm':
                    flags &= ~boost::regex_constants::no_mod_m;
                    break;
                }
            }

            if (inside != std::string::npos)
            {
                m_patterns.push_back(std::make_shared<Pattern>(pattern, flags, lookbehind, greedy, std::string{ alias }, std::make_shared<GrammarPtr>(shared_from_this(), inside)));
            }
            else
            {
                m_patterns.push_back(std::make_shared<Pattern>(pattern, flags, lookbehind, greedy, std::string{ alias }));
            }
        }
    }
}

const Pattern* LanguageTree::resolvePattern(size_t path)
{
    return m_patterns[path].get();
}

const Grammar* LanguageTree::resolveGrammar(size_t path)
{
    return m_grammars[path].get();
}
