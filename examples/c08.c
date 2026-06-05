// Calcula el maximo comun divisor de dos numeros > 0.
// Por ejemplo, la salida esperada para 42 y 56 es 14.
// 450,360->90; 150,180->30; 
//----------------------------------------------------
int max(int x, int y)
{ int z;
  if (x < y) z = y;
  else       z = x;
  return z;
}

int min(int x, int y)
{ int z;
  if (x < y) z = x;
  else       z = y;
  return z;
}

int mcd(int x, int y)
{ int z;
  if (x == y) z = x;
  else        z = mcd(min(x,y-x),max(x,y-x));
  return z;
}

int main()
{ struct { int x; int y; } A; int aux; bool z;

  z=true;
  while ( z ) {
    read(aux);  A.x = aux; read(aux);  A.y = aux;
    if ((A.x > 0) && (A.y > 0)) {
      if (A.x < A.y) print(mcd(A.x,A.y));
      else           print(mcd(A.y,A.x));
      z=false;
    }
    else {}
  }
  
  return 0;
}
