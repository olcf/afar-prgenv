program hello_world
    use mpi
    implicit none

    integer :: mpi_size, mpi_rank, ierr
    character(len=30) :: message

    ! Initialize the MPI environment
    call MPI_Init(ierr)

    ! Get details about this process (rank) and the total number of processes (size)
    call MPI_Comm_size(MPI_COMM_WORLD, mpi_size, ierr)
    call MPI_Comm_rank(MPI_COMM_WORLD, mpi_rank, ierr)

    ! Create a specific message for each process
    write(message, '(A, I0, A, I0)') 'Hello, world! Process ', mpi_rank, ' of ', mpi_size

    ! Print the message from each process (order may be arbitrary)
    write(*,*) trim(message)

    ! Finalize the MPI environment
    call MPI_Finalize(ierr)
end program hello_world
