# -*- Perl -*-

## Compile in _build: targets with starting @ are replaced with _build/,
## possibly adding .tex; symbolic links are created.
if (! -e "_build") {
    mkdir ("_build");
}

sub create_build_file {
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
  \RequirePackage{luacode,luapackageloader}
  \begin{luacode}
    require "lfs"
    
    function loadall(dir)
      for file in lfs.dir(dir) do
        if string.find(file, ".lua$") then
          dofile(dir .. "/".. file)     
        end
      end
    end
    loadall ('lib')
  \end{luacode}
\fi
\input{src/\filename.tex}
END
    open(FH, '>', "_build/${_[0]}") or die $!;
    print FH $master;
    close(FH);
    system ("find src/ -name '*.tex' | sort | sed 's/^/%% /' >> '_build/${_[0]}'");
}

sub all_targets {
    system("find src -name '*.tex' -exec grep -l documentclass '{}' \\; |
                  while read f; do
                    { grep '^%% var:' \$f || echo \$f ; } | sed \"s@%% var: @\$f.@\"
           done | sed 's|^src/\\(.*\\)\\.tex\\(.*\\)|@\\1\\2|' | " . $_[0]);
}

## Clear previous tex files to avoid weird inclusions (especially with subfiles package)
system("find _build -name '*.tex' -exec rm '{}' \\;");

$has_file = 0;
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
        create_build_file ("$f");
        $has_file = 1;
    }
}

if (! $has_file) {
    create_build_file ("main.tex");
}

$ENV{'TEXINPUTS'}='src:lib:img:';
$ENV{'BIBINPUTS'}='src:../src';
$ENV{'BSTINPUTS'}='lib:src:';

$recorder = 1;  # try to use the .fls to notice changed files
$pdf_mode = 4;  # generate PDFs, not DVIs, use lualatex
$bibtex_use = 2;  # run BibTeX/biber when appears necessary
$clean_ext = 'vtc nav snm vrb';  # also clean those extensions when invoking latexmk -c
@default_files = ('_build/main.tex');
$out_dir = '_build/';

$lualatex = 'lualatex --shell-escape %O ./%S'; # Explicitly say ./, which is consistent with do_cd; some versions of lualatex search for %S in TEXINPUTS, so get the src/ one first.

add_cus_dep('org', 'orgtex', 0, 'orgtex');
sub orgtex {
    sleep (1);

    print ("opening ${_[0]}.org");
    open(my $F, '<', "${_[0]}.org") or die $!;
    my $text = join('', <$F>);
    close $F;

    open(DST, '>', "${_[0]}.orgtex") or die $!;

    while ($text =~ /^\s*#\+BEGIN_SRC.*?\n(.*?)\n\s*#\+END_SRC/msig) {
        print DST "$1\n";
    }
    close(DST);
    return 0;
}
