#include <stdio.h>

int main()
{
#pragma omp parallel
{
  printf("Hello from parallel\n");

}

#pragma omp target
{
  printf("Hello from target\n");
}
return 1;
}
