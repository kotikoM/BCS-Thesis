// #set text(font: "Sylfaen")

#let fakebold(content) = {
  set text(stroke: 0.3pt + black)
  content
}

#align(left)[
  #image("../res/KIU2.svg", width: 3.5cm)
]
#line(length: 100%, stroke: 0.5pt)

#v(5%)

#align(center)[

  #fakebold[
    #set text(14pt)
    LEPL Kutaisi International University \
    School of Computer Science \
    Bachelor Program of Computer Science
  ]

  #v(2cm)

  #fakebold[
    #set text(16pt)
    Mirian Shilakadze\
    Mikheili Kvinikadze\
    Konstantine Machavariani
  ]

  #v(2cm)

  #fakebold[
    #set text(16pt)
    C0 to Machine Code:\
    Assembler, Simulator and Basic OS Support.
  ]

  #v(3cm)

  #set text(14pt, weight: "regular")
  Thesis submitted for the degree of Bachelor of Computer Science

  #v(3cm)

  #set text(12pt, weight: "regular")
  Bachelor's Thesis Supervisor: Prof. Dr. Walter Tichy

  #v(1cm)

  Co-supervisor: Prof. Dr. Wolfgang J. Paul

  #v(1fr)

  Kutaisi, 2026
]