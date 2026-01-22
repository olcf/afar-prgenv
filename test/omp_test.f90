program main

!$omp parallel
print *, 'hello parallel'
!$omp end parallel

!$omp target
print *, 'hello target'
!$omp end target

end program
