\usepackage{needspace}
\renewcommand{\thepart}{\Alph{part}}
\makeatletter
\@ifclassloaded{book}{%
  \setlength{\cftbeforechapskip}{0.5em plus 1pt}%
}{}
\makeatother
