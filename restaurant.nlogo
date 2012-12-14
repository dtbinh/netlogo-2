breed [tables table]
breed [guests guest]
breed [waiters waiter]
breed [kitchens kitchen]

tables-own [places free-places orders meals]

;speed je rychlost pohybu hosta
;selected-table je vybrany stul, ke kteremu jde
;state je stav hosta, v ktere casti flow navstevy se nachazi
;meal je jidlo, ktere host ji
guests-own [state choosed-table time meal]

waiters-own [served-tables orders-to-kitchen orders-to-table]

kitchens-own [orders-to-cook orders-cooked]

to setup
  
  ca ;clear all
  reset-ticks
  
  ;guest states
; 0 coming
; 1 seating
; 2 ordering
; 3 waiting
; 4 eating
; 5 paying
; 6 leaving
 
  create-guests guests-count [
      set color white ;hladovi hosti jsou bili
      set size 1
      ;set shape "person"
      setxy random-pxcor random-pycor ;nahodne umisteni hosta, meli by se generovat u dveri
      set choosed-table ""
      set state 0
    ]
  
  create-tables tables-count [
    set color brown
    set places table-seats
    set size 2
    set free-places 4 ;todo pocitat metoda
    set shape "square"
    setxy random-pxcor random-pycor ;nahodne umisteni stolu, jeste predelame, aby byly vic pohromade
    set orders []
    set meals []
    set label self
  ]
  
  create-waiters waiters-count [
    set color blue;
    set size 1
    setxy random-pxcor random-pycor ;nahodne umisteni hosta, meli by se generovat u dveri
    set served-tables [] ;hoste, o ktere se cisnik stara, nepredavaji si je
    set orders-to-kitchen [] ;objednavky, ktere nosi do kuchyne (objednana jidla)
    set orders-to-table [] ;objednavky, ktere nosi z kuchyne na stul (donesena jidla)
  ]
  
  
  create-kitchens 1 [
    set color white;
    set shape "square"
    set size 2
    setxy random-pxcor random-pycor ;nahodne umisteni hosta, meli by se generovat u dveri
    set orders-to-cook []; objednavky k uvareni
    set orders-cooked []; objednavky uvarene, muzou se rozdavat
    set label self
    
  ]
  
  
  ask waiters[
    set served-tables [] ;zatim zadne stoly
    ]
  
  
  ;cisnici si rozdeli stoly
  ask tables [
    
    let waiter min-one-of waiters [ length served-tables ] ; vyber cisnika s nejmensim poctem stolu, ktere obsluhuje. Rozdeli to spravedlive, postupne by meli mit vsichni cisnici stejny pocet stolu.
    
    ask waiter [
      set served-tables lput myself served-tables  ;uloz cisnikovi stul, ktery bude obsluhovat.
      ]    
  ]
  
  
  ;pridej na seznam mist, ktere prochazi taky kuchyn
  ask waiters[
    set served-tables lput one-of kitchens served-tables
  ]  
  
end


to go
  
  ask tables[
    update-free-places ;aktualizuj info o volnych stolech
  ]
    
    
  ask guests[
    ;prijd do restaurace
    guest-seat ;zaber stul
    guest-order
    guest-grab-meal
    guest-eat
    guest-leave
    ;order ;objednavej jidlo
    ;eat ; jez
    ;pay ; plat
    ;leave ;odejdi
    update-time ;aktualizuj cas, ktery ma na obed
    update-label
    ;
    
  ]
  
  
  ask waiters[
    waiter-circle-between-kitchens-and-tables
    waiter-skip-empty-tables
    waiter-pick-up-orders ;vyzvedni objednavky od stolu
    waiter-push-orders ;dej objednavky do kuchyne
    waiter-pull-orders ;vyzvedni hotove objednavky z kuchyne
    waiter-put-orders ;dej jidlo na stul
    waiter-collect-money
    ]
  
  
  ask kitchens[
    kitchen-cook
    ]
  
    
  tick
  
  
end


;cisnici pendluji mezi stolama a kuchyni
to waiter-circle-between-kitchens-and-tables
  
  if empty? served-tables [ stop ] ;nema stoly, nepokracuje (nastane, pokud je cisniku vic nez stolu)
  
  ;bez k prvnimu stolu na seznamu
 
  let table first served-tables ;prvni stul na seznamu
  
  ifelse (at-table? and one-of tables-here = table) or (at-kitchen? and one-of kitchens-here = table)[ ;jsem u stolu nebo v kuchyni, ke kteremu jsem smeroval, rotuj dalsi cil
    ;jakmile jsi u stolu, dej tento stul na konec seznamu a pokracuj k dalsimu prvnimu stolu
    ;rotuj seznam
    set served-tables but-first served-tables ;vynech prvni stul, posun seznam, takze druhy stul bude prvni
    set served-tables lput table served-tables ;a prvni stul dej na konec
  ][
  ;nejsi u stolu, jdi k nemu
  facexy [xcor] of table [ycor] of table ;nasmeruj se
  fd 1 ;jdi o 1 policko
  ]
  
end

;cisnik
;preskoc prazdne stoly
to waiter-skip-empty-tables
  
  let table first served-tables ;prvni stul na seznamu
  
  if [breed] of table = tables [ ;jen stoly, kuchyni nepreskakujeme
    
    let skip false ;zatim nepreskakujeme
    
    ask table[
      set skip count guests-here = 0 ;preskakujeme, pokud u vysledneho stolu neni zadny host
    ]
    
    if skip = true [
      set served-tables but-first served-tables ;vynech prvni stul, posun seznam, takze druhy stul bude prvni
      set served-tables lput table served-tables ;a prvni stul dej na konec
    ]
    
  ]
  
  
end


;cisnik
;predej objednavky do kuchyne
to waiter-push-orders
  
  if not at-kitchen? or empty? orders-to-kitchen [ stop ] ;pokud neni v kuchyni, nebo nema co objednat, nepokracujeme
  
  ask one-of kitchens-here [ ;dej do kuchyne
    
    foreach [orders-to-kitchen] of myself [ ;projdi vsechny cisnikovy objednavky
      set orders-to-cook lput ?1 orders-to-cook ;a kazdou z nich postupne po 1 dej na konec fronty objednavek
    ]
    
  ]
  
  set orders-to-kitchen [] ;predal vsechny objednavky, zadny nema
    
end



;cisnik
;vyzvedni jen MOJE objednavky z kuchyne

to waiter-pull-orders
  
  if not at-kitchen? [ stop ] ;pokud neni v kuchyni, nepokracujeme
   
  ask one-of kitchens-here [ ;vyzvedni z kuchyne
    
    foreach orders-cooked [ ;projdi vsechna jidla pripravena k vydani 
      
      if member? ?1 [served-tables] of myself [;je to objednavka pro stul, ktery obsluhuju? myself=cisnik
        ask myself[ ;cisnik
          set orders-to-table lput ?1 orders-to-table ;seznam objednavek k rozneseni u cisnika (orders-to-table) je prazdny, lep rovnou na konec
        ]             
      ]
    ]
  ]
  
   ;cisnik 
   ask self [
     ;projdi vsechny jeho stoly a zrus objednavky k jeho stolum, prave si je vyzvedl
     foreach served-tables [
       ask one-of kitchens-here [
         set orders-cooked remove ?1 orders-cooked
       ]
     ]
   ]
  
end



;cisnik
;vyzvedni objednavky od stolu
to waiter-pick-up-orders
  
  if not at-table? [ stop ] ;pokud neni u stolu, nema co vyzvedavat
  
  ;nekontroluju, zda vyzvedava objednavku, ktera patri ke stolu, ktery obsluhuje. Proste kdyz ke stolu prisel, ocekavam, ze ho obsluhuje.
  ;vyzvedne vsechny objednavky najednou
   
  ask one-of tables-here[ ;stul u ktereho je cisnik
    
    foreach orders [ ;postupne kazdou objednavku ze stolu
      
      ask myself [ ;cisnik
        set orders-to-kitchen lput ?1 orders-to-kitchen ;presun do objednavek cisnika
      ]
      
    ]
    
    set orders [] ;zrus objednavky na stul, uz je ma vsechny cisnik
    
  ]
  
  
end


;cisnik
;poloz objednavky na stul
to waiter-put-orders
  
  if not at-table? or empty? [orders-to-table] of self [ stop ] ;pokud neni u stolu nebo nema co polozit, koncime
  
  ask self [ ;cisnik
    
    foreach orders-to-table [ ;cisnikovy jidla v ruce
      
      ask one-of tables-here [ ;stul
        if self = ?1[ ;patri jidlo na tento stul?
          set meals lput ?1 meals ;poloz 1 jidlo na stul
        ]
      ]
      
    ]
    
    ;zrus vsechna jidla cisnika k tomuto stolu, uz je rozdal
    set orders-to-table remove (one-of tables-here) orders-to-table ;objednavka je "stul", takze zrus "stoly" ke stolu
    
  ]  
  
end


;cisnik
;kasiruj
to waiter-collect-money
  
  if not at-table? [ stop ] ;pokud neni u stolu nebo nema co polozit, koncime
  
  ask guests-here with [state = "wanna pay"] [
    set state "leaving"
  ]
    
end


to update-time
  
  set time time + 1
  let ratio (time / max-ticks-for-lunch) * 100
  
  if ratio < 50 [ set color green ] 
  if ratio >= 50 and ratio < 100 [ set color orange ]
  if ratio >= 100 [set color red]
  
end



to update-label
  set label state ;item state guest-states
  set label-color color
end


; nahodny pohyb o 1 policko
to move
  rt random 50
  lt random 50
  fd 1
end


;stul
;aktulizuj pocet volnych mist
to update-free-places
   set free-places places - count guests-here 
   ;set label free-places
end


;host
;najdi prazdy stul a jdi k nemu
;posad se
to guest-seat
  
  if at-table? [ stop ] ;pokud jsem u stolu, neposazuju se
  
  ;nema zatim vyhlidnuty stul, najdi ho
  ;pripadne ma stul vybrany, ale je obsazeny, musis najit novy
  ifelse choosed-table = "" or (choosed-table != "" and [free-places] of choosed-table < 1)[
    
    set state "seating" ;seating
    
    let table one-of tables with [free-places > 0 ]
    
    ifelse table != nobody [ ;stul existuje
      facexy [xcor] of table [ycor] of table ;nasmeruj se ke stolu
      set choosed-table table ;uloz stul, ktery jsem vybral
      fd 1 ;jdi ke stolu
    ] [
    ;neni volny stul, co mam delat?
    ;ted stuj
    ]
    
  ] [
  
  ;mam stul a je porad volny, jdu k nemu
  facexy [xcor] of choosed-table [ycor] of choosed-table 
  fd 1;jdi ke stolu
  ]  
  
  ;stul si aktualizuje stav, co kdyby se prave usadil?
  if choosed-table != ""[
    ask choosed-table[
      update-free-places
    ]
  ]
  
end


;objednavka
;musi byt posazeny
;musi u nej byt cisnik
to guest-order
  
  if at-table? and state = "seating" [ set state "ordering" ] ;ordering
  
  if not (state = "ordering" and waiter-here?) [stop] ;jidlo objednavam, jen pokud chci prave objednavat a u stolu je cisnik
  
  ;cisnik je tady, objednavam
 
  ;objednavky jsou na "na stul" ne na "hlavu", cisnici takhle pracuji
  ;objednavka je ted objekt stolu, nebereme v potaz jidlo, pro flow to ted neni dulezite
  ;aka "na tento stul objednavam gulas"
  ask one-of tables-here[
    set orders lput self orders
    ]

  set state "waiting" ;ceka na jidlo  
  
  ;objednavam
  output-print self
  output-print "objednavam"
  
end


;host
;vezmi si jidlo
to guest-grab-meal
  
  if not (state = "waiting") [ stop ] ;pokud neceka na jidlo, nepokracuj
  
  ask one-of tables-here [ ;stul
    
    if not empty? meals [ ;je nejake volne jidlo na stole?
      
      let m first meals ;prvni volne jidlo
      ;TODO jidlo si muzes vzit, jenom pokud budes cekat nejdele, jinak se muze stat, ze zacnes jist jidlo, ktere objednal host pred tebou
      
      ;vezmi si ho
      ask myself[ ;host
        set meal m ;tohle jidlo mam ja
        set state "eating"
      ]
      
      set meals but-first meals ;stul, zmizi jedno volne jidlo, vzal si ho prave host
      
    ]
    
  ]
  
end

;host
;jez jidlo
to guest-eat
  
  if not (state = "eating") [ stop ] ;pokud neji, nepokracuj
  
  if ticks mod max-ticks-needed-for-eating = 0 [
    set meal ""
    set state "wanna pay"
    ]
  
end


;host
;odejdi
to guest-leave
  
  if not (state = "leaving") [ stop ] ;pokud nema odejit, neodchazej
  move
  
end


;kuchyn
;uvar jidlo
to kitchen-cook
  
  if empty? orders-to-cook [ stop ] ;kdyz nic nemam varit, tak nevarim

  ;pripravi jidlo k vydani
  ;TODO lze dat brzdu, treba poisson, apod.
  ;predpokladam, ze je to restaurace v dobe obeda, takze se nevari, ale jen vydavaji obedy (menu), ktere uz jsou uvarene
  ;1 tick = 1 pripravene jidlo
  if ticks mod max-ticks-needed-for-preparing-meal = 0 [ ;pokud jsem dosahl limitu na vydej
    set orders-cooked lput first orders-to-cook orders-cooked ;vem prvni jidlo z fronty a dej ho na konec jidel k vydani
    set orders-to-cook but-first orders-to-cook ;z fronty jidel k priprave zrus prvni polozku, uz je pripraveno k vydani
  ]

end



;jsem u stolu?
to-report at-table?
  report count tables-here > 0
end


;jsem v kuchyni?
to-report at-kitchen?
  report count kitchens-here > 0
end


;host
;je u me nejaky cisnik?
to-report waiter-here?
  report any? waiters-here
end


@#$#@#$#@
GRAPHICS-WINDOW
693
32
1262
492
21
16
13.0
1
10
1
1
1
0
0
0
1
-21
21
-16
16
0
0
1
ticks
30.0

SLIDER
73
43
245
76
tables-count
tables-count
1
10
10
1
1
NIL
HORIZONTAL

BUTTON
73
254
139
287
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
280
255
343
288
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
170
254
251
287
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
264
44
436
77
guests-count
guests-count
0
100
100
1
1
NIL
HORIZONTAL

MONITOR
73
311
165
356
awaiting waiter
count guests with [state = \"awaiting-waiter\"]
17
1
11

SLIDER
451
44
623
77
waiters-count
waiters-count
1
10
10
1
1
NIL
HORIZONTAL

MONITOR
187
312
281
357
finding-table
count guests with [state = \"finding-table\"]
17
1
11

SLIDER
73
96
255
129
max-ticks-for-lunch
max-ticks-for-lunch
1
1000
541
1
1
NIL
HORIZONTAL

SLIDER
265
97
437
130
table-seats
table-seats
1
6
4
1
1
NIL
HORIZONTAL

PLOT
72
400
586
577
guest satisfaction
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"ok" 1.0 0 -10899396 true "" "plot count guests with [color = green]"
"in rush" 1.0 0 -955883 true "" "plot count guests with [color = orange]"
"unsatisfied" 1.0 0 -2674135 true "" "plot count guests with [color = red]"

SLIDER
72
152
368
185
max-ticks-needed-for-preparing-meal
max-ticks-needed-for-preparing-meal
1
100
10
1
1
NIL
HORIZONTAL

OUTPUT
694
511
1261
609
12

SLIDER
73
201
311
234
max-ticks-needed-for-eating
max-ticks-needed-for-eating
1
100
20
1
1
NIL
HORIZONTAL

MONITOR
297
614
364
659
ordering
count guests with [state = \"ordering\"]
17
1
11

MONITOR
379
614
450
659
wanna pay
count guests with [state = \"wanna pay\"]
17
1
11

MONITOR
462
615
519
660
leaving
count guests with [state = \"leaving\"]
17
1
11

MONITOR
160
614
218
659
seating
count guests with [state = \"seating\"]
17
1
11

MONITOR
233
614
283
659
waiting
count guests with [state = \"waiting\"]
17
1
11

MONITOR
616
622
896
667
NIL
length [orders-to-cook] of one-of kitchens
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
