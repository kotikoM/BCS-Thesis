#show figure.where(kind: raw): set figure(supplement: [Code])
// main.typ
#set page(margin: (left: 3cm, right: 1.5cm, top: 2.5cm, bottom: 2.5cm))
#set par(
  first-line-indent: 2em,
  spacing: 0.75em,
  justify: true
)
#set list(indent: 1em)
#set enum(indent: 1em)
#show figure: f => {[#v(0.8em) #f #v(1em) ]}
#show heading.where(depth: 1): it => (
  it +
  v(0.3cm)
)
#show math.equation.where(block: true): e => [
    #box(width: 100%, inset: 0em, [
        #set align(center)
        #e
    ])
]
#set heading(supplement: [Chapter])
#show figure.where(kind: raw): set figure(supplement: [Code])

// Title page
// (Sylfaen is set at the top of kiuTitle.typ — uncomment it there when compiling via CLI)
#include "start/kiuTitle.typ"
// #set text(font: "Times New Roman") // uncomment to switch 
#pagebreak()

#set page(numbering: "I")
#counter(page).update(1)
#include "start/declaration.typ"
#pagebreak()
#include "start/abstract.typ"
#pagebreak()

// Table of Contents
#outline()
#pagebreak()

#set page(numbering: "1")
#counter(page).update(1)
#set heading(numbering: "1.")

// Main part
#include "chapters/intro.typ"
#pagebreak()
#set par(first-line-indent: 0cm)
#include "chapters/mips.typ"
#include "chapters/assembler.typ"
#include "chapters/compiler.typ"
#pagebreak()
#set par(first-line-indent: 2em)
#include "chapters/simulator.typ"
#pagebreak()
#include "chapters/runvm.typ"
#pagebreak()
#include "chapters/conclusion.typ"
#pagebreak()
#bibliography("res/bibl.yml", style: "ieee")
#pagebreak()
#set heading(supplement: [Section])
#include "chapters/appendix.typ"