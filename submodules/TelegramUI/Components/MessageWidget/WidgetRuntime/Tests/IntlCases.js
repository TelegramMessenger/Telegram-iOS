// widget-sandbox v0.1.1's Intl parity fixture (third-party/widget-sandbox/fixtures/intl-cases.json: requests as the
// framework's shim sends them, with V8's answers), each request run as the call a widget would make. Shared by the host
// test (Tests/IntlCasesTests.cpp, over a host answering from the fixture) and the iOS one
// (WidgetRuntimeIOS/Tests/WRIntlCasesTests.swift, through widget-sandbox's iOS glue), which set the global
// `intlCasesText` to the fixture's text; the completion value is one line per case that does not answer as V8 did,
// "<id> ## got <answer>, want <V8's>", where <id> is the request as JSON (the drift list's key).
(() => {
    const fixture = JSON.parse(intlCasesText);
    // The fixture's rule: U+00A0, U+202F and U+2009 compare as spaces.
    const spaces = s => String(s).replace(/[   ]/g, ' ');
    const parts = list => list.map(p => [p.type, spaces(p.value)]);
    const answer = r => {
        switch (r.kind) {
        case 'number': return new Intl.NumberFormat(r.locale, r.opts).format(r.value);
        case 'numberParts': return new Intl.NumberFormat(r.locale, r.opts).formatToParts(r.value);
        case 'numberOptions': return new Intl.NumberFormat(r.locale, r.opts).resolvedOptions();
        case 'date': return new Intl.DateTimeFormat(r.locale, r.opts).format(r.value);
        case 'dateParts': return new Intl.DateTimeFormat(r.locale, r.opts).formatToParts(r.value);
        case 'dateOptions': return new Intl.DateTimeFormat(r.locale, r.opts).resolvedOptions();
        case 'dateMethod': return new Date(r.value)[r.method](r.locale, r.opts);
        case 'plural': return new Intl.PluralRules(r.locale, r.opts).select(r.value);
        case 'relative': return new Intl.RelativeTimeFormat(r.locale, r.opts).format(r.value, r.unit);
        case 'list': return new Intl.ListFormat(r.locale, r.opts).format(r.value);
        case 'compare': return String(Math.sign(new Intl.Collator(r.locale, r.opts).compare(r.a, r.b)));
        case 'upper': return r.value.toLocaleUpperCase(r.locale);
        case 'lower': return r.value.toLocaleLowerCase(r.locale);
        }
        throw new Error('unknown request kind ' + r.kind);
    };
    // Strings as spaces normalised, parts as [type, value] lists, options on the keys V8's answer lists.
    const same = (expected, got) => {
        if (Array.isArray(expected)) {
            return Array.isArray(got) && JSON.stringify(parts(got)) === JSON.stringify(parts(expected));
        }
        if (expected !== null && typeof expected === 'object') {
            return got !== null && typeof got === 'object' &&
                Object.keys(expected).every(k => JSON.stringify(got[k]) === JSON.stringify(expected[k]));
        }
        return spaces(got) === spaces(expected);
    };
    const shown = v => (v !== null && typeof v === 'object') ? JSON.stringify(Array.isArray(v) ? parts(v) : v) : JSON.stringify(spaces(v));
    const out = [];
    for (const c of fixture.cases) {
        let got;
        try {
            got = answer(c.request);
        } catch (e) {
            got = 'threw ' + e;
        }
        if (!same(c.expected, got)) {
            out.push(JSON.stringify(c.request) + ' ## got ' + shown(got) + ', want ' + shown(c.expected));
        }
    }
    return out.join('\n');
})()
