/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "func.h"
#include "parser/srcread.h"
#include "parser/lexer.h"
#include "parser/symtable.h"
#include <getopt.h>
#include <fstream>

namespace funC {

int verbosity, indent, opt_level = 2;
bool stack_layout_comments, op_rewrite_comments, program_envelope, asm_preamble;
std::ostream* outs = &std::cout;
std::string generated_from, boc_output_filename;

/*
 * 
 *   OUTPUT CODE GENERATOR
 * 
 */

void generate_output_func(SymDef* func_sym) {
  SymValCodeFunc* func_val = dynamic_cast<SymValCodeFunc*>(func_sym->value);
  assert(func_val);
  std::string name = sym::symbols.get_name(func_sym->sym_idx);
  if (verbosity >= 2) {
    std::cerr << "\n\n=========================\nfunction " << name << " : " << func_val->get_type() << std::endl;
  }
  if (!func_val->code) {
    std::cerr << "( function `" << name << "` undefined )\n";
  } else {
    CodeBlob& code = *(func_val->code);
    if (verbosity >= 3) {
      code.print(std::cerr, 9);
    }
    code.simplify_var_types();
    if (verbosity >= 5) {
      std::cerr << "after simplify_var_types: \n";
      code.print(std::cerr, 0);
    }
    code.prune_unreachable_code();
    if (verbosity >= 5) {
      std::cerr << "after prune_unreachable: \n";
      code.print(std::cerr, 0);
    }
    code.split_vars(true);
    if (verbosity >= 5) {
      std::cerr << "after split_vars: \n";
      code.print(std::cerr, 0);
    }
    for (int i = 0; i < 8; i++) {
      code.compute_used_code_vars();
      if (verbosity >= 4) {
        std::cerr << "after compute_used_vars: \n";
        code.print(std::cerr, 6);
      }
      code.fwd_analyze();
      if (verbosity >= 5) {
        std::cerr << "after fwd_analyze: \n";
        code.print(std::cerr, 6);
      }
      code.prune_unreachable_code();
      if (verbosity >= 5) {
        std::cerr << "after prune_unreachable: \n";
        code.print(std::cerr, 6);
      }
    }
    code.mark_noreturn();
    if (verbosity >= 3) {
      code.print(std::cerr, 15);
    }
    if (verbosity >= 2) {
      std::cerr << "\n---------- resulting code for " << name << " -------------\n";
    }
    bool inline_ref = (func_val->flags & 2);
    *outs << std::string(indent * 2, ' ') << name << " PROC" << (inline_ref ? "REF" : "") << ":<{\n";
    code.generate_code(
        *outs,
        (stack_layout_comments ? Stack::_StkCmt | Stack::_CptStkCmt : 0) | (opt_level < 2 ? Stack::_DisableOpt : 0),
        indent + 1);
    *outs << std::string(indent * 2, ' ') << "}>\n";
    if (verbosity >= 2) {
      std::cerr << "--------------\n";
    }
  }
}

int generate_output() {
  if (asm_preamble) {
    *outs << "\"Asm.fif\" include\n";
  }
  *outs << "// automatically generated from " << generated_from << std::endl;
  if (program_envelope) {
    *outs << "PROGRAM{\n";
  }
  for (SymDef* func_sym : glob_func) {
    SymValCodeFunc* func_val = dynamic_cast<SymValCodeFunc*>(func_sym->value);
    assert(func_val);
    std::string name = sym::symbols.get_name(func_sym->sym_idx);
    *outs << std::string(indent * 2, ' ');
    if (func_val->method_id.is_null()) {
      *outs << "DECLPROC " << name << "\n";
    } else {
      *outs << func_val->method_id << " DECLMETHOD " << name << "\n";
    }
  }
  int errors = 0;
  for (SymDef* func_sym : glob_func) {
    try {
      generate_output_func(func_sym);
    } catch (src::Error& err) {
      std::cerr << "cannot generate code for function `" << sym::symbols.get_name(func_sym->sym_idx) << "`:\n"
                << err << std::endl;
      ++errors;
    }
  }
  if (program_envelope) {
    *outs << "}END>c\n";
  }
  if (!boc_output_filename.empty()) {
    *outs << "2 boc+>B \"" << boc_output_filename << "\" B>file\n";
  }
  return errors;
}

}  // namespace funC

void usage(const char* progname) {
  std::cerr
      << "usage: " << progname
      << " [-vIAPSR][-O<level>][-i<indent-spc>][-o<output-filename>][-W<boc-filename>] {<func-source-filename> ...}\n"
         "\tGenerates Fift TVM assembler code from a funC source\n"
         "-I\tEnables interactive mode (parse stdin)\n"
         "-o<fift-output-filename>\tWrites generated code into specified file instead of stdout\n"
         "-v\tIncreases verbosity level (extra information output into stderr)\n"
         "-i<indent>\tSets indentation for the output code (in two-space units)\n"
         "-A\tPrefix code with `\"Asm.fif\" include` preamble\n"
         "-O<level>\tSets optimization level (2 by default)\n"
         "-P\tEnvelope code into PROGRAM{ ... }END>c\n"
         "-S\tInclude stack layout comments in the output code\n"
         "-R\tInclude operation rewrite comments in the output code\n"
         "-W<output-boc-file>\tInclude Fift code to serialize and save generated code into specified BoC file. Enables "
         "-A and -P.\n";
  std::exit(2);
}

std::string output_filename;

int main(int argc, char* const argv[]) {
  int i;
  bool interactive = false;
  while ((i = getopt(argc, argv, "Ahi:Io:O:PRSvW:")) != -1) {
    switch (i) {
      case 'A':
        funC::asm_preamble = true;
        break;
      case 'I':
        interactive = true;
        break;
      case 'i':
        funC::indent = std::max(0, atoi(optarg));
        break;
      case 'o':
        output_filename = optarg;
        break;
      case 'O':
        funC::opt_level = std::max(0, atoi(optarg));
        break;
      case 'P':
        funC::program_envelope = true;
        break;
      case 'R':
        funC::op_rewrite_comments = true;
        break;
      case 'S':
        funC::stack_layout_comments = true;
        break;
      case 'v':
        ++funC::verbosity;
        break;
      case 'W':
        funC::boc_output_filename = optarg;
        funC::asm_preamble = funC::program_envelope = true;
        break;
      case 'h':
      default:
        usage(argv[0]);
    }
  }

  if (funC::program_envelope && !funC::indent) {
    funC::indent = 1;
  }

  funC::define_keywords();
  funC::define_builtins();

  int ok = 0, proc = 0;
  try {
    while (optind < argc) {
      funC::generated_from += std::string{"`"} + argv[optind] + "` ";
      ok += funC::parse_source_file(argv[optind++]);
      proc++;
    }
    if (interactive) {
      funC::generated_from += "stdin ";
      ok += funC::parse_source_stdin();
      proc++;
    }
    if (ok < proc) {
      throw src::Fatal{"output code generation omitted because of errors"};
    }
    if (!proc) {
      throw src::Fatal{"no source files, no output"};
    }
    std::unique_ptr<std::fstream> fs;
    if (!output_filename.empty()) {
      fs = std::make_unique<std::fstream>(output_filename, fs->trunc | fs->out);
      if (!fs->is_open()) {
        std::cerr << "failed to create output file " << output_filename << '\n';
        return 2;
      }
      funC::outs = fs.get();
    }
    funC::generate_output();
  } catch (src::Fatal& fatal) {
    std::cerr << "fatal: " << fatal << std::endl;
    std::exit(1);
  } catch (src::Error& error) {
    std::cerr << error << std::endl;
    std::exit(1);
  } catch (funC::UnifyError& unif_err) {
    std::cerr << "fatal: ";
    unif_err.print_message(std::cerr);
    std::cerr << std::endl;
    std::exit(1);
  }
}
