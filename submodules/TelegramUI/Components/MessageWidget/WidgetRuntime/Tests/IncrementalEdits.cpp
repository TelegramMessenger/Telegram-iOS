#include "Tests/IncrementalEdits.h"

#include "Sources/Host/ThemeParams.h"

namespace wr_test {

std::string editPage(const std::string& sheet, const std::string& filler, const std::string& prefix) {
    return "<!doctype html><style>" + sheet + "</style><body style='margin:0'>" + prefix +
           "<div id=a class=box><p class=x>alpha <b>bold</b> text</p><p>beta</p><span class=y>gamma</span></div>"
           "<ul id=l><li>one</li><li class=x>two</li><li>three</li></ul>"
           "<table id=t>\n<caption>cap</caption>\n<thead><tr><td>h1</td></tr></thead>\n"
           "<tbody><tr><td>c1</td><td class=y>c2</td></tr>\n<tr><td>c3</td><td>c4</td></tr></tbody>\n</table>"
           "<pre id=pre>pre  text\n line</pre>"
           "<div id=f><input value=ab><input type=checkbox checked><button value=ab>ab</button><button disabled>d</button>"
           "<button>go</button></div>"
           "<svg width=30 height=30 viewBox='0 0 30 30'><circle cx=15 cy=15 r=10 fill=red></circle></svg>"
           "<template id=tpl><i class=x>tpl one</i><b>tpl two</b></template>"
           "<div id=c class=y>tail</div>" + filler + "</body>";
}

const char* const kEditHelpersJS = R"JS(
globalThis.__edit = (() => {
  const tpl = document.getElementById('tpl');
  const excluded = n => n.id === 'filler' || n.id === 'filler2' || n.id === 'inputs' || n.id === 'mass' ||
                       n.localName === 'template';
  let stashedBody = null;
  function walk(root, out) {
    for (let n = root.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 1 && excluded(n)) continue;
      if (n.nodeType !== 1 && n.nodeType !== 3) continue;
      out.push(n);
      if (n.nodeType === 1) walk(n, out);
    }
    return out;
  }
  const nodes = () => walk(document.body, []);
  const elements = () => nodes().filter(n => n.nodeType === 1);
  const containers = () => [document.body].concat(elements());
  const texts = () => nodes().filter(n => n.nodeType === 3);
  const pick = (list, i) => list.length ? list[i % list.length] : null;
  function el(tag, attrs, kids) {
    const e = document.createElement(tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    for (const c of kids) e.append(c);
    return e;
  }
  function make(k) {
    switch (k % 17) {  // kEditShapes
      case 0: return document.createTextNode('new text');
      case 1: return el('p', {class: 'x'}, ['para ', el('b', {}, ['in'])]);
      case 2: return el('span', {class: 'y'}, ['sp']);
      case 3: return el('li', {}, ['item']);
      case 4: return el('div', {class: 'box'}, [el('p', {}, ['inner']), el('span', {}, ['s'])]);
      case 5: return el('button', {value: 'zz'}, ['zz']);
      case 6: return el('b', {}, ['b']);
      case 7: return el('tr', {}, [el('td', {}, ['r1']), el('td', {class: 'y'}, ['r2'])]);
      case 8: return el('q', {}, ['quote']);
      case 9: {
        const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        s.setAttribute('width', '10'); s.setAttribute('height', '10');
        const r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        r.setAttribute('width', '5'); r.setAttribute('height', '5'); r.setAttribute('fill', 'blue');
        s.append(r);
        return s;
      }
      case 10: return el('pre', {}, ['p  re\n x']);
      // Tables as the parser makes them (whitespace a <table> refuses, row groups, a caption) and as script can (rows
      // and a div straight under a <table>, which its appendChild refuses), and the parts that go into one.
      case 12: return el('table', {}, ['\n', el('caption', {}, ['cap']), '\n', el('thead', {}, [el('tr', {}, [el('td', {}, ['h'])])]),
                                       el('tbody', {}, [el('tr', {}, [el('td', {}, ['b'])])]), '\n']);
      case 13: return el('table', {}, [el('tr', {}, [el('td', {}, ['r'])]), el('div', {}, ['refused div']), ' ']);
      case 14: return el('tbody', {}, ['\n', el('tr', {}, [el('td', {class: 'y'}, ['tb'])])]);
      case 15: return el('caption', {}, ['c']);
      case 16: return el('input', {value: 'zz'}, []);
      default: return document.createTextNode(' ');
    }
  }
  const words = ['', 'a', 'two words', 'three little words', 'x & <y>', '  spaced  out  ', 'longer text that wraps around the line',
                 'a much longer text that certainly wraps across more than one line at this width'];
  const htmls = ['', '<b>b</b> text', '<p class=x>p</p><span class=y>s</span>', '<li>l1</li><li class=x>l2</li>', 'plain',
                 '<i>i</i><input value=q>', '<q>q</q>'];
  const classes = ['', 'x', 'y', 'x y', 'box', 'z'];
  const styles = ['', 'color:#090', 'padding:3px', 'display:none', 'font-size:20px', 'background:#ccc;margin:2px'];
  const varStyles = ['', '--k:#00f', 'color:var(--k, #c00)', '--g:3px;padding:var(--g)', 'background:var(--k)',
                     '--d:none;display:var(--d, block)'];
  const attributeValues = {cx: ['5', '12'], r: ['3', '9'], width: ['8', '20'], height: ['6', '18'], d: ['M0 0 L10 10', 'M2 2 H8 V8'],
                           viewBox: ['0 0 10 10', '0 0 30 30'], transform: ['translate(2,1)', 'rotate(10)'], fill: ['blue', 'none'],
                           'data-k': ['1', '2'], value: ['v', 'longer value'], href: ['#x', 'https://example.org/'],
                           dir: ['rtl', 'auto'], lang: ['ru', 'en'], id: ['k1', 'k2'], title: ['t', 'tt']};
  const boxStyles = ['position:absolute;left:3px;top:4px', 'position:relative;top:2px', 'float:left;width:40px',
                     'display:inline-block', 'display:flex', 'display:list-item', 'display:table-cell',
                     'border-width:3px;border-style:solid', 'white-space:pre', 'font-size:9px', 'z-index:2;position:relative'];
  const sheets = ['', '[data-k]{background:#cfc}', '.pc::before{content:"\\00bb"}', '@media (max-width:300px){p{display:none}}',
                  'li{display:inline}', ':hover{outline:2px solid #f00}'];
  return (kind, a, b, c) => {
    try {
      switch (kind) {
        case 0: { const p = pick(containers(), a), n = make(b); p.append(n); return 'append ' + (n.localName || '#text'); }
        case 1: {
          const p = pick(containers(), a), n = make(b);
          p.insertBefore(n, p.childNodes[c % (p.childNodes.length + 1)] || null);
          return 'insertBefore ' + (n.localName || '#text');
        }
        case 2: { const n = pick(nodes(), a); if (n) n.remove(); return 'remove'; }
        case 3: {
          const n = pick(nodes(), a), p = pick(containers(), b);
          if (n) p.insertBefore(n, p.childNodes[c % (p.childNodes.length + 1)] || null);
          return 'move';
        }
        case 4: { const e = pick(elements(), a); if (e) e.textContent = words[b % words.length]; return 'textContent'; }
        case 5: { const e = pick(elements(), a); if (e) e.innerHTML = htmls[b % htmls.length]; return 'innerHTML'; }
        case 6: { const e = pick(elements(), a); if (e) e.setAttribute('class', classes[b % classes.length]); return 'class'; }
        case 7: { const e = pick(elements(), a); if (e) e.setAttribute('style', styles[b % styles.length]); return 'style'; }
        case 8: {
          const e = pick(elements(), a);
          if (e) { if (e.hasAttribute('hidden')) e.removeAttribute('hidden'); else e.setAttribute('hidden', ''); }
          return 'hidden';
        }
        case 9: { const t = pick(texts(), a); if (t) t.data = words[b % words.length]; return 'data'; }
        // textContent on an element whose only child is a Text: the text path's swap (RenderTree::textSwaps).
        case 20: {
          const e = pick(elements().filter(e => e.childNodes.length === 1 && e.firstChild.nodeType === 3), a);
          if (e) e.textContent = words[b % words.length];
          return 'swap';
        }
        case 12: {
          // A row group or a caption into a table, before one of its children (whitespace included), or a refused subtree.
          const tables = elements().filter(e => e.localName === 'table');
          const t = pick(tables, a);
          if (!t) return 'table insert (no table)';
          const part = [make(14), make(15), el('thead', {}, [el('tr', {}, [el('td', {}, ['th'])])]), make(13)][b % 4];
          t.insertBefore(part, t.childNodes[c % (t.childNodes.length + 1)] || null);
          return 'table insert';
        }
        case 21: {
          const e = pick(elements(), a);
          if (!e) return 'attribute (none)';
          const svg = e.namespaceURI === 'http://www.w3.org/2000/svg';
          const names = svg ? ['cx', 'r', 'width', 'height', 'd', 'viewBox', 'transform', 'fill']
                            : ['data-k', 'value', 'href', 'dir', 'lang', 'id', 'title'];
          const name = names[b % names.length];
          if (c % 3 === 0) { e.removeAttribute(name); return 'remove ' + name; }
          e.setAttribute(name, attributeValues[name][c % 2]);
          return 'attribute ' + name;
        }
        case 22: { const e = pick(elements(), a); if (e) e.setAttribute('style', boxStyles[b % boxStyles.length]); return 'box style'; }
        case 23: {
          let s = document.getElementById('s2');
          if (c % 4 === 0) {
            if (s) { s.remove(); return 'sheet removed'; }
            s = document.createElement('style'); s.id = 's2'; document.head.append(s);
            return 'sheet inserted';
          }
          if (!s) { s = document.createElement('style'); s.id = 's2'; document.head.append(s); }
          s.textContent = sheets[b % sheets.length];
          return 'sheet text';
        }
        case 24: {
          const e = [document.documentElement, document.body][a % 2];
          const name = ['class', 'style', 'dir'][b % 3];
          e.setAttribute(name, {class: ['', 'x', 'y'], style: ['margin:0', 'margin:0;color:#090', 'margin:0;font-size:14px'],
                                dir: ['ltr', 'rtl', 'auto']}[name][c % 3]);
          return 'document element ' + name;
        }
        case 25: { const e = pick(elements(), a); if (e) e.classList.toggle('pc'); return 'pc class'; }
        case 26: { const e = pick(elements(), a); if (e) e.setAttribute('style', varStyles[b % varStyles.length]); return 'var style'; }
        case 27: {
          // Inside an <svg>: a <circle> or a <g> holding a <rect> into a picked svg or <g>, or one of their children out.
          const parents = elements().filter(e => e.localName === 'svg' || e.localName === 'g');
          const p = pick(parents, a);
          if (!p) return 'svg content (no svg)';
          if (c % 3 === 0 && p.firstElementChild) { p.firstElementChild.remove(); return 'svg child removed'; }
          const ns = 'http://www.w3.org/2000/svg';
          let n;
          if (b % 2) {
            n = document.createElementNS(ns, 'circle');
            n.setAttribute('cx', String(5 + c % 20)); n.setAttribute('cy', '10'); n.setAttribute('r', '4'); n.setAttribute('fill', 'green');
          } else {
            n = document.createElementNS(ns, 'g');
            const r = document.createElementNS(ns, 'rect');
            r.setAttribute('x', '2'); r.setAttribute('y', '2'); r.setAttribute('width', '6'); r.setAttribute('height', '6');
            n.append(r);
          }
          p.insertBefore(n, p.childNodes[c % (p.childNodes.length + 1)] || null);
          return 'svg ' + n.localName + ' inserted';
        }
        case 28: {
          // The document's own children (twidget edit 82).
          if (b % 4 === 0) {
            const h = document.documentElement.cloneNode(true);
            const body = h.querySelector('body');
            if (body) { const p = document.createElement('p'); p.textContent = 'cloned ' + c; body.append(p); }
            document.documentElement.replaceWith(h);
            return 'document element replaced';
          }
          if (b % 4 === 1) { document.append(document.createComment('c' + c)); return 'document comment'; }
          if (b % 4 === 2) {
            const n = [...document.childNodes].find(x => x.nodeType === 8);
            if (n) n.remove();
            return 'document comment removed';
          }
          document.documentElement.className = ['x', 'y', ''][c % 3];
          if (document.body) document.body.append(make(a));
          return 'document element class beside an append';
        }
        case 29: {
          // The document's own head and body.
          const html = document.documentElement;
          if (!html) return 'no document element';
          switch (b % 5) {
            case 0:
              if (document.head) { document.head.remove(); return 'head removed'; }
              html.prepend(document.createElement('head'));
              return 'head inserted';
            case 1:
              if (document.body) { stashedBody = document.body; stashedBody.remove(); return 'body removed'; }
              html.append(stashedBody || document.createElement('body'));
              stashedBody = null;
              return 'body put back';
            case 2: {
              if (!document.body) return 'no body';
              const nb = document.createElement('body');
              nb.append(...document.body.childNodes);
              document.body = nb;
              return 'document.body set';
            }
            case 3: {
              const old = document.body;
              const nb = document.createElement('body');
              nb.append(make(a));
              html.insertBefore(nb, old);
              if (old) old.id = 'o' + c;
              return 'body inserted before the body';
            }
            default: {
              const e = pick(elements(), a);
              if (e) e.append(document.createElement('body'));
              return 'body element appended under ' + (e ? e.localName : 'nothing');
            }
          }
        }
        case 30: {
          // A <br>'s attributes.
          const br = document.querySelector('body br');
          if (!br) { pick(containers(), a).append(document.createElement('br')); return 'br inserted'; }
          const set = [['class', 'x'], ['class', 'box'], ['id', 'k' + c], ['style', 'display:block;height:3px'],
                       ['style', '']][b % 5];
          br.setAttribute(set[0], set[1]);
          return 'br ' + set[0];
        }
        case 31: {
          // 5,000 changes in one batch, each its own journal entry.
          let m = document.getElementById('mass');
          if (!m) {
            if (!document.body) return 'no body';
            m = document.createElement('div');
            m.id = 'mass';
            document.body.append(m);
            return 'mass container';
          }
          if (!m.firstChild) {
            for (let i = 0; i < 5000; i++) { const s = document.createElement('span'); s.textContent = 'm'; m.append(s); }
            return 'mass appended';
          }
          if (b % 2 === 0) {
            const cls = classes[c % classes.length];
            for (let s = m.firstChild; s; s = s.nextSibling) s.className = cls;
            return 'mass class';
          }
          while (m.firstChild) m.firstChild.remove();
          return 'mass removed';
        }
        case 10: tpl.content.append(make(b)); return 'template append';
        default: {
          const n = tpl.content.firstChild, p = pick(containers(), a);
          if (n) p.append(n);
          return 'template move out';
        }
      }
    } catch (e) {
      return 'threw ' + e.name;
    }
  };
})(); 'ok'
)JS";

const char* const kEnvironmentSheet =
    " :hover{outline:1px solid #f0f} @media (prefers-color-scheme:dark){p,li{color:#eee;background-color:#223}}"
    " @media (prefers-reduced-motion:reduce){li{padding-left:9px}}";

std::string themeDeclarations(wr::Theme theme) {
    return wr::themeRootDeclarations(wr::completeThemeParams({}, theme), theme);
}

} // namespace wr_test
