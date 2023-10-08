#########################################
#                                       #
#   Makefile for the Touch utility      #
#  Remove /Zi & /co after debugging     #
#                                       #
#########################################


touch.obj : touch.asm touch.mak
    masm /Zi /Mx $*;

touch.exe : touch.obj touch.mak
    link /co $*,,,doscalls + djo,$*
