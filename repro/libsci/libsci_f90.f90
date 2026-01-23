program libsci_blas
  implicit none
  integer, parameter :: n = 2
  double precision :: a(n,n), b(n,n), c(n,n)
  double precision :: alpha, beta

  a = 0.0d0
  b = 0.0d0
  c = 0.0d0
  a(1,1) = 1.0d0
  a(2,2) = 1.0d0
  b(1,1) = 1.0d0
  b(1,2) = 2.0d0
  b(2,1) = 3.0d0
  b(2,2) = 4.0d0
  alpha = 1.0d0
  beta = 0.0d0

  call dgemm('N', 'N', n, n, n, alpha, a, n, b, n, beta, c, n)
  print *, 'C(1,1)=', c(1,1)
end program libsci_blas
