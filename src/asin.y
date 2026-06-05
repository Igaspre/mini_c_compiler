/*****************************************************************************/
/** Analizador sintactico-semantico y generacion de codigo (BISON).         **/
/** Proyecto academico de un compilador de C-- (curso 2023-2024).           **/
/** Desarrollado por un equipo de 4 estudiantes.                            **/
/*****************************************************************************/

%{
#include <stdio.h>
#include <string.h>
#include "libtds.h" 
#include "header.h"
#include "libgci.h"

/**** Funciones auxiliares ****/
int comp_tipos(int t1, int t2, int toperador, int toperandos, char* menerror);
int comp_tipos_var(int t1, int t2, char* menerror);
%}

%union {/********************************************************************/
  int cent;       /* Valor de la cte numerica entera para el terminal "cte" */        
  char *ident;    /* Nombre del identificador */
  int aux;        /* Atributo auxiliar para funciones */
  Reg reg;        /* Lista atributos de struct y parámetros */ 
  Exp exp;        /* Lista atributos de las expresiones */
  Op op;          /* Lista atributos de los operadores */  
  Ref ref;        /* Lista atributos para guardar referencias */
}/***************************************************************************/


/***************************** Palabras reservadas **************************/
%token BOOL_ INT_ STRUCT_ FALSE_ TRUE_ READ_ PRINT_ IF_ ELSE_ WHILE_ RETURN_
/*********************************** Operadores */
%token ASIG_ AND_ OR_ NOT_ IGUAL_ DIST_ MY_ MYIG_ MN_ MNIG_
%token MAS_ MENOS_ POR_ DIV_ MAS2_ MENOS2_
/*********************************** Otros simbolos */
%token AL_ CL_ AC_ CC_ AP_ CP_ PTO_ COMA_ PCOMA_
/*********************************** con atributos */
%token <ident> ID_
%token <cent> CTE_

/*************************** Tipos de no terminales ***************************/
%type <cent> tipoSimp 
%type <reg> listCamp paramForm listParamForm paramAct listParamAct
%type <aux> declaFunc
%type <exp> expre expreLogic expreIgual expreRel expreAd expreMul expreUna 
expreSufi const 
%type <op> opUna opLogic opIgual opRel opAd opMul opIncre



%%
programa      :     { 
                        /* Inicializar las variables globales del compilador */
                        dvar=0; niv=0; si=0; cargaContexto(niv);

                        /* Reservar espacio variables globales del programa */
                        /* Incrementamos si hasta llegar a la pila de instrucciones, esta despues de todo lo de dvar */
                        $<ref.ref1>$ = creaLans(si);
                        emite(INCTOP, crArgNul(), crArgNul(), crArgEnt(-1));

                        /* Emitir el salto al comienzo de la funcióm main */
                        $<ref.ref2>$ = creaLans(si);
                        emite(GOTOS, crArgNul(), crArgNul(), crArgEtq(-1));
                    }   
                listDecla 
                    { 
                        /* Completar reserva espacio para variables globales programa */
                        /* Completamos salto a pila de instrucciones */
                        completaLans($<ref.ref1>1, crArgEnt(dvar));

                        SIMB simb = obtTdS("main");
                        /* Comprobar si el programa tiene main */
                        if (simb.t == T_ERROR) 
                            yyerror("No se ha encontrado la función main");
                        /* Completar salto al comienzo de la función main (desplazamiento a la primera instruccion del main en la pila de instrucciones) */
                        else {
                            completaLans($<ref.ref2>1, crArgEtq(simb.d));
                        }
                    }
              ;
listDecla     : decla 
              | listDecla decla
              ;
decla         : declaVar
              | declaFunc
              ;
declaVar      : tipoSimp ID_ PCOMA_
                    {
                        /* Declaración de variable de tipo simple */
                        if (!insTdS($2, VARIABLE, $1, niv, dvar, -1)) {
                            yyerror("Variable ya declarada");
                        }
                        else dvar += TALLA_TIPO_SIMPLE;
                    }
              | tipoSimp ID_ AC_ CTE_ CC_ PCOMA_
                    {   
                        /* Declaración de lista */
                        int numelem = $4;
                        if ($4 <= 0) {
                            yyerror("Talla inapropiada del array");
                            numelem = 0;
                        }
                        int ref = insTdA($1, numelem);
                        if (!insTdS($2, VARIABLE, T_ARRAY, niv, dvar, ref)) {
                            yyerror ("Identificador repetido");
                        }
                        else dvar += numelem * TALLA_TIPO_SIMPLE;
                    }
              | STRUCT_ AL_ listCamp CL_ ID_ PCOMA_
                    {
                        /* Declaración de struct */
                        if (!insTdS($5, VARIABLE, T_RECORD, niv, dvar, $3.ref)) {
                            yyerror ("Nombre de variable ya definido");
                        }
                        else dvar += $3.talla;
                    }
              ;
tipoSimp      : INT_  
                    { $$ = T_ENTERO; }
              | BOOL_ 
                    { $$ = T_LOGICO; }
              ;
listCamp      : tipoSimp ID_ PCOMA_
                    {
                        int refe = insTdR(-1, $2, $1, 0);
                        if (refe == -1)  
                            yyerror ("Nombre de campo ya definido");
                        $$.talla = TALLA_TIPO_SIMPLE;
                        $$.ref = refe;
                    }
              | listCamp tipoSimp ID_ PCOMA_
                    {
                        int refe_nueva = insTdR($1.ref, $3, $2, $1.talla);
                        if (refe_nueva == -1)  
                            yyerror ("Nombre de campo ya definido");
                        $$.talla = $1.talla + TALLA_TIPO_SIMPLE;
                        $$.ref = refe_nueva;
                    }
              ;
declaFunc     : tipoSimp ID_ 
                    { 
                        /* Gestión del contexto y guardar dvar */
                        niv = niv + 1; 
                        cargaContexto(niv); 
                        $<aux>$ = dvar; 
                        dvar = 0; 
                    }
                AP_ paramForm CP_ 
                    {
                        /* Insertar información de la función en la TdS */
                        if (!insTdS($2, FUNCION, $1, niv-1, si, $5.ref)) {
                            yyerror("Función declarada anteriormente");
                            if (strcmp($2, "main\0") == 0) { yyerror("Más de una función main declarada"); }
                        }

                        /*** Carga registro de activación, bloque llamado ***/
                        /* Cargar los enlaces de control (Modificaciones del FP del RA) */
                        emite(PUSHFP, crArgNul(), crArgNul(), crArgNul());
                        emite(FPTOP, crArgNul(), crArgNul(), crArgNul());

                        /* Reserva de espacio para variables locales y temporales */
                        /* Incrementamos el sp (cima de la pila) con la dirección final (sp = sp + SV.talla) */
                        $<ref.ref1>$ = creaLans(si);
                        emite(INCTOP, crArgNul(), crArgNul(), crArgEnt(-1));    
                    }
                AL_ declaVarLocal listInst RETURN_ expre PCOMA_
                    {
                        /* Comprobación de tipos del RETURN, separamos de CL para mostrar el error en la línea del return */
                            if (!($1 == $12.tipo)) {
                                yyerror("Tipo de la función distinto del tipo retornado"); 
                            }  
                    }
                CL_
                    {
                        /* Continuación modificaciones del FP. Ver tema 6 final y explicación de su gestión en el tema 5*/
                        
                        /* Cálculo del desplazamiento del valor retorno en el RA (DeclaFunc siempre devuelve un tipoSimple) */
                        int dvr  = TALLA_SEGENLACES + $5.talla + TALLA_TIPO_SIMPLE;

                        /* Completa reserva espacio para variables locales y temporales */
                        completaLans($<ref.ref1>7, crArgEnt(dvar));

                        /* Guardar valor de retorno (Desde el FP, la dirección del valor de retorno en el RA esta a -dvr, ya que desde el FP comienza en 0) */
                        emite(EASIG, crArgPos(niv, $12.d), crArgNul(), crArgPos(niv, -dvr));
                            
                        /*** Descarga del registro de activación bloque llamado ***/
                        /* Libera el segmento de variables locales y temporales */
                        emite(TOPFP, crArgNul(), crArgNul(), crArgNul() );

                        /* Descarga de los enlaces de control */
                        emite(FPPOP, crArgNul(), crArgNul(), crArgNul() );

                        /* Emite FIN si es main y RETURN si no lo es */
                        if (strcmp($2, "main\0") == 0) {
                            emite(FIN, crArgNul(), crArgNul(), crArgNul());
                        } else {
                            /* Desapila la dirección de retorno y transfiere el control a dicha dirección (dirección desde la que le han llamado) */
                            emite(RET, crArgNul(), crArgNul(), crArgNul());
                        }

                        /* Mostrar la información de la función en la TdS */
                        if (verTdS) mostrarTdS();

                        /* Gestión del contexto y recuperar dvar */
                        descargaContexto(niv); 
                        niv--; 
                        dvar = $<aux>3;
                    }
              ;
paramForm     : /* cadena vacia */
                    { 
                        /* Si no hay parámetros, creamos dominio de tipo vacío */
                        $$.ref = insTdD(-1, T_VACIO);
                        $$.talla = 0;
                    }
              | listParamForm
                    {
                        $$.ref = $1.ref;
                        $$.talla = $1.talla - TALLA_SEGENLACES;
                    }
              ;
listParamForm : tipoSimp ID_
                    {
                        /* Primer parámetro del dominio de la función */
                        /* -1 indica que es el primer parametro, crea nueva entrada en la TdD para el tipo del parametro y devuelve su referencia */
                        $$.ref = insTdD(-1, $1);
                        $$.talla = TALLA_TIPO_SIMPLE + TALLA_SEGENLACES;
                        if (!insTdS($2, PARAMETRO, $1, niv, -$$.talla, -1)) {
                            yyerror("Parámetro de la función repetido");
                        }
                    }
              | tipoSimp ID_ COMA_ listParamForm
                    {
                        $$.ref = insTdD($4.ref, $1);
                        $$.talla = $4.talla + TALLA_TIPO_SIMPLE;
                        if (!insTdS($2, PARAMETRO, $1, niv, -$$.talla, -1)) {
                            yyerror("Parámetro de la función repetido");
                        } 
                    }
              ;
declaVarLocal :    /* cadena vacia */
              | declaVarLocal declaVar
              ;
listInst      :    /* cadena vacia */
              | listInst inst
              ;
inst          : AL_ listInst CL_
              | instExpre
              | instEntSal
              | instSelec
              | instIter
              ;
instExpre     : expre PCOMA_
              | PCOMA_
              ;
instEntSal    : READ_ AP_ ID_ CP_ PCOMA_
                    {
                        SIMB simb = obtTdS($3);
                        comp_tipos_var(simb.t, T_ENTERO, "El argumento de read no es tipo entero");

                        emite(EREAD, crArgNul(), crArgNul(), crArgPos(simb.n, simb.d));
                    }
              | PRINT_ AP_ expre CP_ PCOMA_
                    {
                        /* Escribimos mensaje de error solo si expre no es ya error, ya que si es error se ha escrito antes */
                        if ($3.tipo != T_ERROR && $3.tipo != T_ENTERO)
                            yyerror("El argumento de print no es un entero");

                        emite(EWRITE, crArgNul(), crArgNul(), crArgPos(niv, $3.d));
                    }
              ;
instSelec     : IF_ AP_ expre CP_
                    {
                        /* Escribimos mensaje de error solo si expre no es ya error, ya que si es error se ha escrito antes */
                        if ($3.tipo != T_ERROR && $3.tipo != T_LOGICO) 
                            yyerror("La condición del IF debe ser de tipo lógico");

                        $<ref.ref1>$ = creaLans(si);
                        emite(EIGUAL, crArgPos(niv, $3.d), crArgEnt(0), crArgEtq(-1));
                    }
                inst 
                    {
                        $<ref.ref1>$ = creaLans(si);
                        emite(GOTOS, crArgNul(), crArgNul(), crArgEtq(-1));
                        completaLans ($<ref.ref1>5, crArgEtq(si));
                    }
                ELSE_ inst
                    {
                        completaLans ($<ref.ref1>7, crArgEtq(si));
                    }
              ;
instIter      : WHILE_ 
                    {
                        $<ref.ref1>$ = si;
                    }
                AP_ expre CP_
                    {
                        /* Escribimos mensaje de error solo si expre no es ya error, ya que si es error se ha escrito antes */
                        if ($4.tipo != T_ERROR && $4.tipo != T_LOGICO) 
                            yyerror("La condición del WHILE debe ser de tipo lógico");

                        $<ref.ref2>$ = creaLans(si);
                        emite(EIGUAL, crArgPos(niv, $4.d), crArgEnt(0), crArgEtq(-1));
                    }
                inst
                    {
                        emite(GOTOS, crArgNul(), crArgNul(), crArgEtq($<ref.ref1>2));
                        completaLans ($<ref.ref2>6, crArgEtq(si));
                    }
              ;
expre         : expreLogic
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    } 
              | ID_ ASIG_ expre
                    {  
                        SIMB simb = obtTdS($1);
                        $$.tipo = comp_tipos_var(simb.t, $3.tipo, "Tipo de la variable distinto del tipo asignado");

                        emite(EASIG, crArgPos(niv, $3.d), crArgNul(), crArgPos(simb.n, simb.d));
                        $$.d = creaVarTemp();
                        emite(EASIG, crArgPos(simb.n, simb.d), crArgNul(), crArgPos(niv, $$.d));
                    }
              | ID_ AC_ expre CC_ ASIG_ expre
                    {
                        SIMB simb = obtTdS($1);
                        int tipo = comp_tipos_var(simb.t, T_ARRAY, "La variable no es un array");
                        if (tipo != T_ERROR) {
                            if ($3.tipo == T_ENTERO){
                                DIM dim = obtTdA(simb.ref);
                                tipo = comp_tipos_var(dim.telem, $6.tipo, "Tipo del array distinto del tipo del elemento asignado");
                            } else {
                                tipo = T_ERROR;
                                yyerror("El índice de acceso debe ser un entero");
                            }
                        }
                        $$.tipo = tipo;     

                        emite(EVA, crArgPos(simb.n, simb.d), crArgPos(niv, $3.d), crArgPos(niv, $6.d)); 
                        $$.d = creaVarTemp();
                        emite(EAV,crArgPos(simb.n, simb.d), crArgPos(niv, $3.d), crArgPos(niv, $$.d));
                    }
              | ID_ PTO_ ID_ ASIG_ expre
                    {
                        SIMB simb = obtTdS($1);
                        int tipo = comp_tipos_var(simb.t, T_RECORD, "La variable no es un struct");
                        int desp;
                        if (tipo != T_ERROR) {
                            CAMP camp = obtTdR(simb.ref, $3);
                            tipo = comp_tipos_var(camp.t, $5.tipo, "Tipo del elemento del struct, distinto del tipo asignado");

                            desp = simb.d + camp.d;
                            emite(EASIG, crArgPos(niv, $5.d), crArgNul(), crArgPos(simb.n, desp));
                            $$.d = creaVarTemp();
                            emite(EASIG, crArgPos(simb.n, desp), crArgNul(), crArgPos(niv, $$.d));
                        }
                        $$.tipo = tipo;  
                    }
              ;
expreLogic    : expreIgual
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    }
              | expreLogic opLogic expreIgual
                    {
                        /*Expresiones AND y OR. Solo se puede con expresiones lógicas*/
                        $$.tipo = comp_tipos($1.tipo, $3.tipo, $2.tipo, T_LOGICO, "Necesita tipos lógicos para la operación");
                    
                        $$.d = creaVarTemp();
                        if ($2.op == EMULT) { /* AND */
                            emite($2.op, crArgPos(niv, $1.d), crArgPos(niv, $3.d), crArgPos(niv, $$.d));
                        } else { /* OR */
                            emite($2.op, crArgPos(niv, $1.d), crArgPos(niv, $3.d), crArgPos(niv, $$.d));
                            emite(EMENEQ, crArgPos(niv, $$.d), crArgEnt(1), crArgEtq(si + 2));
                            emite(EASIG, crArgEnt(1), crArgNul(), crArgPos(niv, $$.d));
                        }
                    }
              ;
expreIgual    : expreRel
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    }
              | expreIgual opIgual expreRel
                    {
                        /* Expresiones == y !=. Devuelve una expresión lógica */
                        if ($3.tipo == T_LOGICO) 
                            $$.tipo = comp_tipos($1.tipo, $3.tipo, $2.tipo, T_LOGICO, "Tipos incompatibles, ambos deben ser enteros o lógicos");
                        else 
                            $$.tipo = comp_tipos($1.tipo, $3.tipo, $2.tipo, T_ENTERO, "Tipos incompatibles, ambos deben ser enteros o lógicos");
                    
                        $$.d = creaVarTemp();
                        emite(EASIG, crArgEnt(1), crArgNul(), crArgPos(niv, $$.d));
                        emite($2.op, crArgPos(niv, $1.d), crArgPos(niv, $3.d), crArgEtq(si + 2));
                        emite(EASIG, crArgEnt(0), crArgNul(), crArgPos(niv, $$.d));
                    }
              ;
expreRel      : expreAd
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    }
              | expreRel opRel expreAd
                    {
                        /*Expresiones >, <, >=, <=. Devuelve una expresión Lógica*/
                        $$.tipo = comp_tipos($1.tipo, $3.tipo, $2.tipo, T_ENTERO, "Necesita tipos enteros para la operación");
                    
                        $$.d = creaVarTemp();
                        emite(EASIG, crArgEnt(1), crArgNul(), crArgPos(niv, $$.d));
                        emite($2.op, crArgPos(niv, $1.d), crArgPos(niv, $3.d), crArgEtq(si + 2));
                        emite(EASIG, crArgEnt(0), crArgNul(), crArgPos(niv, $$.d));
                    }
              ;
expreAd       : expreMul
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    }
              | expreAd opAd expreMul
                    {
                        /* Expresiones "+ -" Devuelve un entero */
                        $$.tipo = comp_tipos($1.tipo, $3.tipo, $2.tipo, T_ENTERO, "Necesita tipos enteros para la operación");
                        
                        $$.d = creaVarTemp();
                        emite($2.op, crArgPos(niv, $1.d), crArgPos(niv, $3.d), crArgPos(niv, $$.d));
                    }
              ;
expreMul      : expreUna
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    }
              | expreMul opMul expreUna
                    {
                        /*Expresiones *, /. Devuelve un entero*/
                        $$.tipo = comp_tipos($1.tipo, $3.tipo, $2.tipo, T_ENTERO, "Necesita tipos enteros para la operación");
                    
                        $$.d = creaVarTemp();
                        emite($2.op, crArgPos(niv, $1.d), crArgPos(niv, $3.d), crArgPos(niv, $$.d));
                    }
              ;
expreUna      : expreSufi
                    {
                        $$.tipo = $1.tipo;
                        $$.d = $1.d;
                    }
              | opUna expreUna
                    {
                        /*Expresiones +x, -x, !x. Devuelve un entero o valor lógico*/
                        $$.tipo = comp_tipos($1.tipo, $2.tipo, $1.tipo, $1.tipo, "Operación incompatible con el tipo del objeto");
                        
                        $$.d = creaVarTemp();
                        if ($1.op == ESIG) {
                            emite(EDIF, crArgEnt(1), crArgPos(niv, $2.d), crArgPos(niv, $$.d));    
                        } else {
                            emite($1.op, crArgEnt(0), crArgPos(niv, $2.d), crArgPos(niv, $$.d));
                        }
                    }
              | opIncre ID_
                    {
                        SIMB simb = obtTdS($2);
                        $$.tipo = comp_tipos_var(simb.t, $1.tipo, "El tipo de la variable debe ser entero");

                        /* Incrementar y después asignar */
                        $$.d = creaVarTemp();
                        emite($1.op, crArgPos(simb.n, simb.d), crArgEnt(1), crArgPos(simb.n, simb.d));
                        emite(EASIG, crArgPos(simb.n, simb.d), crArgNul(), crArgPos(niv, $$.d));
                    }
              ;
expreSufi     : const 
                    { 
                        $$.tipo = $1.tipo; 
                        $$.d = creaVarTemp();
                        emite(EASIG, crArgEnt($1.d), crArgNul(), crArgPos(niv, $$.d));
                    }
              | AP_ expre CP_ 
                    { 
                        $$.tipo = $2.tipo;
                        $$.d = $2.d;
                    }
              | ID_
                    {
                        SIMB simb = obtTdS($1);
                        $$.tipo = comp_tipos_var(simb.t, simb.t, "Objeto no declarado");

                        $$.d = creaVarTemp();
                        emite(EASIG, crArgPos(simb.n, simb.d), crArgNul(), crArgPos(niv, $$.d));
                    }
              | ID_ opIncre
                    {
                        SIMB simb = obtTdS($1);
                        $$.tipo = comp_tipos_var(simb.t, $2.tipo, "El tipo de la variable debe ser entero");

                        $$.d = creaVarTemp();
                        /*Asignar y después incrementar*/
                        emite(EASIG, crArgPos(simb.n, simb.d), crArgNul(), crArgPos(niv, $$.d)); 
                        emite($2.op, crArgPos(simb.n, simb.d), crArgEnt(1), crArgPos(simb.n, simb.d));                    
                    }
              | ID_ PTO_ ID_
                    {
                        SIMB simb = obtTdS($1);
                        int tipo = comp_tipos_var(simb.t, T_RECORD, "La variable no es un struct");
                        if (tipo != T_ERROR) {
                            CAMP camp = obtTdR(simb.ref, $3);
                            if(camp.t != T_ERROR){
                                tipo = camp.t;
                                int desp = simb.d + camp.d;
                                $$.d = creaVarTemp();
                                emite(EASIG, crArgPos(simb.n, desp), crArgNul(), crArgPos(niv, $$.d));
                            }
                            else {
                                tipo = T_ERROR;
                                yyerror("No existe variable con ese nombre en la struct");
                            }
                        }
                        $$.tipo = tipo;
                    }
              | ID_ AC_ expre CC_
                    {
                        SIMB simb = obtTdS($1);
                        int tipo = comp_tipos_var(simb.t, T_ARRAY, "La variable no es un array");
                        if (tipo != T_ERROR) {
                            if ($3.tipo == T_ENTERO) {
                                DIM dim = obtTdA(simb.ref);
                                tipo = dim.telem;
                            }
                            else {
                                tipo = T_ERROR;
                                yyerror("Índice de array no es de tipo entero positivo");
                            }
                        }
                        $$.tipo = tipo;
                        $$.d = creaVarTemp();
                        emite(EAV, crArgPos(simb.n, simb.d), crArgPos(niv, $3.d), crArgPos(niv, $$.d)); 
                    }
              | ID_ AP_ 
                    {
                        /* Reservar espacio para el valor de retorno */
                        emite(INCTOP, crArgNul(), crArgNul(), crArgEnt(TALLA_TIPO_SIMPLE)); 
                    }
                paramAct CP_
                    {
                        SIMB simb = obtTdS($1);
                        if (simb.t == T_ERROR) {
                            $$.tipo = T_ERROR;
                            yyerror("Objeto no declarado");
                        } else if (simb.c != FUNCION) {
                            $$.tipo = T_ERROR;
                            yyerror("La variable debe ser una función");
                        } else {
                            INF inf = obtTdD(simb.ref);
                            if (inf.tipo == T_ERROR) {
                                $$.tipo = T_ERROR;
                                yyerror("Función no declarada");
                            } else if (!cmpDom(simb.ref, $4.ref)) {
                                $$.tipo = T_ERROR;
                                yyerror("Error en el dominio de los parámetros actuales");
                            } else {
                                $$.tipo = inf.tipo;
                            }

                            /*** Carga registro activación, bloque llamador ***/
                            /* Llamada a la función */
                            /* Call apila ya la dirección de retorno */
                            emite(CALL, crArgNul(), crArgNul(), crArgEtq(simb.d));
                            
                            /*** Descarga registro activación, bloque llamador ***/
                            /* Desapilar el segmento de parámetros */
                            emite(DECTOP, crArgNul(), crArgNul(), crArgEnt(inf.tsp)); 

                            /* Desapilar y asignar el valor de retorno */
                            $$.d = creaVarTemp();
                            emite(EPOP, crArgNul(), crArgNul(), crArgPos(niv, $$.d));
                        }
                    }
              ;
const         : CTE_   { $$.tipo = T_ENTERO; $$.d = $1; }
              | TRUE_  { $$.tipo = T_LOGICO; $$.d = 1; }
              | FALSE_ { $$.tipo = T_LOGICO; $$.d = 0; }
              ;
paramAct      :    /* cadena vacia */
                    { 
                        /* Si no hay parámetros, creamos dominio de tipo vacío */
                        $$.ref = insTdD(-1, T_VACIO);
                        $$.talla = 0;
                    }
              | listParamAct
                    {
                        $$.ref = $1.ref;
                        $$.talla = $1.talla - TALLA_SEGENLACES;
                    }

listParamAct  : expre
                    {
                        $$.ref = insTdD(-1, $1.tipo);
                        $$.talla = TALLA_TIPO_SIMPLE + TALLA_SEGENLACES;

                        emite(EPUSH, crArgNul(), crArgNul(), crArgPos(niv, $1.d));
                    }
              | expre COMA_ 
                    /*
                    Los parámetros se añadian a la tabla al revés porque la tabla se contruia de arriba a abajo. 
                    Como estamos haciendo push a la pila, hacemos push en el orden correcto de los parámetros
                    */
                    { 
                        emite(EPUSH, crArgNul(), crArgNul(), crArgPos(niv, $1.d)); 
                    } 
                listParamAct
                    {
                        $$.ref = insTdD($4.ref, $1.tipo);
                        $$.talla = $4.talla + TALLA_TIPO_SIMPLE;
                    }
              ;
opLogic       : AND_    { $$.op = EMULT; $$.tipo = T_LOGICO;  }
              | OR_     { $$.op = ESUM; $$.tipo = T_LOGICO; }
              ;
opIgual       : IGUAL_  { $$.op = EIGUAL; $$.tipo = T_LOGICO; }
              | DIST_   { $$.op = EDIST; $$.tipo = T_LOGICO; }
              ;
opRel         : MY_     { $$.op = EMAY; $$.tipo = T_LOGICO; }
              | MN_     { $$.op = EMEN; $$.tipo = T_LOGICO; }
              | MYIG_   { $$.op = EMAYEQ; $$.tipo = T_LOGICO; }
              | MNIG_   { $$.op = EMENEQ; $$.tipo = T_LOGICO; }
              ;
opAd          : MAS_    { $$.op = ESUM; $$.tipo = T_ENTERO; }
              | MENOS_  { $$.op = EDIF; $$.tipo = T_ENTERO; }
              ;
opMul         : POR_    { $$.op = EMULT; $$.tipo = T_ENTERO; }
              | DIV_    { $$.op = EDIVI; $$.tipo = T_ENTERO; }
              ;
opUna         : MAS_    { $$.op = ESUM; $$.tipo = T_ENTERO; }
              | MENOS_  { $$.op = EDIF; $$.tipo = T_ENTERO; }
              | NOT_    { $$.op = ESIG; $$.tipo = T_LOGICO; }
              ;
opIncre       : MAS2_   { $$.op = ESUM; $$.tipo = T_ENTERO; }
              | MENOS2_ { $$.op = EDIF; $$.tipo = T_ENTERO; }
              ;
%%


/******* Funciones Auxiliares *******/
/* Función para comprobar tipos de las expresion */
int comp_tipos(int t1, int t2, int toperador, int toperandos, char* menerror) {
    if (t1 == T_ERROR || t2 == T_ERROR) return T_ERROR; 
    else if (!(t1 == t2 && t1 == toperandos)) {
        yyerror(menerror);
        return T_ERROR;
    }
    else return toperador;
}

/* Función para comprobar tipos con variables */
int comp_tipos_var(int tvar, int t1, char* menerror) {
    if (tvar == T_ERROR) {
        yyerror("Objeto no declarado");
        return T_ERROR;
    } 
    else if (t1 != T_ERROR && tvar != t1) {
        yyerror(menerror);
        return T_ERROR;
    }
    /* Ambos casos, T_ERROR o el tipo de la asignación */
    return t1;
}