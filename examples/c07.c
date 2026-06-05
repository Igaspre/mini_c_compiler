// Calcula el factorial de un numero > 0 y < 13
//---------------------------------------------
int factorial(int n)
{ int f;

  if (n <= 1) f=1;
  else f= n * factorial(n-1);
  
  return f;
}

int main()
{ int x; bool ok;

  ok=true;
  while ( ok ) {
    read(x);
    if ((x > 0) && (x < 13)) {
      print(factorial(x));
      ok=false;
     }
     else {}
  }
  
  return 0;
}
