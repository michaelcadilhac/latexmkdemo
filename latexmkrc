# -*- Perl -*-

## Compile in _build: targets with starting @ are replaced with _build/,
## possibly adding .tex; symbolic links are created.
if (! -e "_build") {
    mkdir ("_build");
}

if (! -e "_build/master.tex") {
    my $master = <<'END';
\RequirePackage{pgfkeys,xstring}
\pgfqkeys{/vars}{.unknown/.code={\pgfkeyssetvalue{\pgfkeyscurrentkey}{#1}}}
\def\varpath{/vars}
\RequirePackage{xparse}
\ExplSyntaxOn
\NewDocumentCommand{\UTFjobname}{o}
 {
  \tl_set_rescan:NnV \l_tmpa_tl { } \c_sys_jobname_str
  \IfNoValueTF{#1}
   { \tl_use:N \l_tmpa_tl }
   { \tl_set_eq:NN #1 \l_tmpa_tl }
 }
\cs_generate_variant:Nn \tl_set_rescan:Nnn {NnV}
\ExplSyntaxOff
\UTFjobname[\utfjobname]
\def\uqji#1#2\relax{%
  \ifx"#1%
    \uqjii#2%
  \else
    \let\unquotedjobname\utfjobname
  \fi}
\def\uqjii#1"{\def\unquotedjobname{#1}}
\expandafter\uqji\utfjobname\relax
\StrBehind*{\unquotedjobname}{.}[\args]
\StrBefore*{\unquotedjobname.}{.}[\filename]
\expandafter\pgfqkeys\expandafter{\expandafter\varpath\expandafter}\expandafter{\args}
\RequirePackage{iftex}
\ifLuaTeX
  \RequirePackage{luacode}
  \begin{luacode}
    require "lfs"
    
    function loadall(dir)
      for file in lfs.dir(dir) do
        if string.find(file, ".lua$") then
          dofile(dir .. "/".. file)     
        end
      end
    end
    loadall ('../lib')
  \end{luacode}
\fi
\input{../src/\filename.tex}
END
    open(FH, '>', "_build/master.tex") or die $!;
    print FH $master;
    close(FH);
}

## Remove current symlinks to master.tex
system ("find _build -type l -exec rm '{}' \\;");

sub all_targets {
    system("find src -name '*.tex' -exec grep -l documentclass '{}' \\; |
                  while read f; do
                    { grep '^%% var:' \$f || echo \$f ; } | sed \"s@%% var: @\$f.@\"
           done | sed 's|^src/\\(.*\\)\\.tex\\(.*\\)|@\\1\\2|' | " . $_[0]);
}

$has_link = 0;
for (@ARGV) {
    if ($_ eq "\@list") {
        all_targets ("sort");
        exit 0;
    }
    if ($_ eq "\@all") {
        all_targets ("xargs -d '\n' -n 1 latexmk");
        exit 0;
    }
    if (/^@/) {
        unless (/\.tex$/) { s/$/.tex/ };
        s/^@//;
        $f=$_;
        s/^/_build\//;
        system("ln -f -s master.tex \"_build/$f\"");
        $has_link = 1;
    }
}

if (! $has_link) {
    system ("ln -f -s master.tex _build/main.tex;");
}

$ENV{'TEXINPUTS'}='../src:../lib:../img:./:';
$ENV{'BIBINPUTS'}='../src:';
$ENV{'BSTINPUTS'}='../lib:../src:';

$recorder = 1;  # try to use the .fls to notice changed files
$pdf_mode = 4;  # generate PDFs, not DVIs, use lualatex
$bibtex_use = 2;  # run BibTeX/biber when appears necessary
$clean_ext = 'vtc nav snm vrb';  # also clean those extensions when invoking latexmk -c
@default_files = ('_build/main.tex');
$do_cd = 1;
$lualatex = 'lualatex --shell-escape %O ./%S'; # do_cd=1 implies that './' is correct; some lualatex versions need this in order to search for the file at the correct place.

add_cus_dep('org', 'orgtex', 0, 'orgtex');
sub orgtex {
  $dir = dirname($_[0]);
  $file = basename($_[0]);
  system ("emacs --batch --eval \"(progn (require 'org) (org-babel-tangle-file \\\"$dir/$file.org\\\" \\\"$dir/${file}.orgtex\\\"))\"");
}
