#ifndef LITEHTML_EL_BEFORE_AFTER_H
#define LITEHTML_EL_BEFORE_AFTER_H

#include "html_tag.h"

namespace litehtml
{
    class el_before_after_base : public html_tag
    {
      public:
        el_before_after_base(const std::shared_ptr<document>& doc, bool before);

        void add_style(const style& style) override;
        ~el_before_after_base() override; // Telegram (VENDOR.md edit 19)
        // Telegram (VENDOR.md edit 78): whether its content holds counter() or counters().
        bool reads_counters() const { return m_reads_counters; }

      private:
        bool               m_reads_counters = false;
        void               add_text(const std::string& txt);
        void               add_function(const std::string& fnc, const std::string& params);
        static std::string convert_escape(const char* txt);
    };

    class el_before : public el_before_after_base
    {
      public:
        explicit el_before(const std::shared_ptr<document>& doc) :
            el_before_after_base(doc, true)
        {
        }
    };

    class el_after : public el_before_after_base
    {
      public:
        explicit el_after(const std::shared_ptr<document>& doc) :
            el_before_after_base(doc, false)
        {
        }
    };
} // namespace litehtml

#endif // LITEHTML_EL_BEFORE_AFTER_H
