# FB_AXIM_X3
FreeBasic Emulador de PDA Pocket-PC Modelo DELL AXIM X3 escrito enteramente en Basic

Modelo con CPU PXA260, 240x320 y 64mb de RAM

Basado en el emulador: (realmente "convertido" sin apenas cambios)
https://github.com/uARM-Palm/uARM 


Quedan cosas por reparar y sobre todo, por optimizar. Aún va muy lento,pero no mucho mas que el original, escrito en C.
El Original requiere de aproximadamente 20seg. para su inicio completo, mientras que esta versión FreeBasic necesita 90seg.
Probado en un I7 3.4ghz, mientras que en un I5 2.1ghz se hace inviable, debido a que tarda casi 5min en iniciarse.

Debe necesariamente compilarse en modo 64bits, por el uso al empleo de "LongInt" en muchas operaciones.
Ademas, es "obligatorio" emplear el parámetro "-gen gcc" de Frebasic al compilar, para emplear únicamente el modo GCC , y no el modo GAS.
Esto es debido a que se utilizan varias llamadas "__builtin_xxx" de control de "overflow" y conteo de bits que solo GCC permite.

La ROM necesaria, por razones obvias, no se incluye:
95efc73fc8bb952eba86c8517ffd50ce025f9666ba94778cff59907802fd90f3  AximX3.NOR.bin

Solo funciona la ROM indicada, ninguna mas de momento, aunque estoy probando otras, por ahora, sin éxito.
