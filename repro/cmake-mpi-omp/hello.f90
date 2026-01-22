program hello_mpi_omp
  use mpi
  implicit none
  integer :: ierr, rank

  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)

!$omp parallel
  if (rank == 0) then
    print *, 'Hello from Fortran + OpenMP + MPI'
  end if
!$omp end parallel

  call MPI_Finalize(ierr)
end program hello_mpi_omp
