cmake_minimum_required(VERSION 3.18)
project(afar_cmake_mpi_omp C Fortran)

find_package(MPI REQUIRED)
find_package(OpenMP REQUIRED)

add_executable(c_hello hello.c)
target_link_libraries(c_hello MPI::MPI_C OpenMP::OpenMP_C)

add_executable(f_hello hello.f90)
target_link_libraries(f_hello MPI::MPI_Fortran OpenMP::OpenMP_Fortran)
