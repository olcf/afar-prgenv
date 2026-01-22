#include <mpi.h>
#include <omp.h>
#include <stdio.h>

int main(int argc, char **argv)
{
  int rank = 0;
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

#pragma omp parallel
  {
    if (rank == 0 && omp_get_thread_num() == 0) {
      printf("Hello from C + OpenMP + MPI\n");
    }
  }

  MPI_Finalize();
  return 0;
}
