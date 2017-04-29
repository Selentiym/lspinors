program compute
    use constants
    use matrix
    use lspinors
    use laguerre
    use integrate
    implicit none
    !Тема диплома  L-spinor basis set for relativistic calculations of Highly Charged Ions
    !На русском Использование базиса L-спиноров в релятивистских расчетах электронной структуры многозарядных ионов

    !Длина базиса, по которому раскладывается радиальная часть ВФ
    !Это число совпадает для верхней и нижней компонент
    integer :: N
    !Число узлов квадратурной формулы
    integer :: qLen
    !Хранят узлы и веса квадратурной формулы соответственно.
    !Длина всегда N + 1, чтобы интегрировать перекрестные м. элементы точно
    real(WP), allocatable::x(:),w(:)
    !Счетчики
    integer :: i, j, k, l
    !Квантовые числа. Пока что главное число - kappa
    real(WP):: quantN, quantJ, quantL, kappa
    !Зарядовое число. Непонятно, откуда оно взялось, если учесть, что
    !потенциал пока что должен быть произвольным
    real(WP)::Z
    !Всякий мусор сюда можно кидать, а также какое-нибудь трапециевое интегрирование
    real(WP)::summa
    !Параметр растяжения по координате. Предполагается, что радиальная часть
    !волновой функции раскладывается по L(xScale * x), в статье было
    !xScale = 2*lambda, однако мне удобнее вынести соответствующие множители в
    real(WP)::xScale
    !Сдвиг степени квадратуры. Смотри модуль интегрирования за более подробными комментариями
    real(WP)::qOffset
    !Тут начинаются переменные для матричных элементов
    !Перекрестные скалярные произведения L-спиноров (пока что радиальных частей)
    real(WP), allocatable::gram(:,:,:,:)
    !Матричные элементы потенциала
    real(WP), allocatable::V(:,:,:,:)
    !Матричные элементы с 1/x
    real(WP), allocatable::revLen(:,:,:,:)
    !Матричные элементы с производной
    real(WP), allocatable::deriv(:,:,:,:)
    !Гамильтониан и правая часть
    real(WP), allocatable::Ham(:,:), S(:,:), E(:)
    !Задает тип базиса
    character::letter
    !Тестовые переменные
    real(WP), allocatable::testV(:)
    real(WP), allocatable::testM(:,:)


    !print *, "Select basis type. P - laguerre Polynomials, L - L-spinors"
    open(unit=18, file='program.ini')
    read (18,*) letter
    read(18, *) N
    read(18, *) kappa
    read(18, *) Z
    read(18, *) xScale
    read(18, *) qOffset

    quantJ = abs(kappa) - 0.5_WP

    open(unit=19,file="matrix_output.dat",status="replace")
    write(19,*) ""
    close(19)

    !kappa = 1.0_WP
    !Z = 1.0_WP
    close(18)
    !read *, letter
    !Читаем длину базиса
    !print *, "Specify basis length for each component"
    !read *, N

    !Вычисляем число узлов квадратуры и выделяем память на узлы и веса
    !алгебраическая точность квадратурной формулы Гусса-Лагерра равна
    ! 2*qLen - 1. Чтобы интегрировать произведения полиномов Лагерра (степень 2*N),
    !нужно взять такую qLen:
    qLen = 2*N + 2
    !qLen = max(N+1, 3000)
    !Матрица производных не получается антисимметричной, так как мы считаем производную
    !именно от базисной функции, а там дифференцируется X**alpha, который должен уходить в
    !формулу квадратуры, а после дифференцирования получается alpha*X**alpha / X,
    !который как раз и дает проблему!
    call setQuadratureParameters(qLen, 2.0D+00 * calculateGamma(kappa, Z),qOffset)
    call setQuadratureArgumentScale(xScale)
    call setBasisScale(xScale)
    call setLspinorGlobalParameters(N, kappa, Z, getIntegrateGridLength(), getIntegrateGrid())
    !allocate(testV(qLen))
    !Проблемы с 0 порядком
    !testV = lspinorVector(0, 'U')
    !print *, testV
    !deallocate (testV)
    !Вдруг понадобятся узлы квадратуры в глобальном контексте в дальнейшем
    allocate (x(qLen))

    allocate(gram(1:2,1:2,N,N))
    allocate(V(1:2,1:2,N,N))
    allocate(deriv(1:2,1:2,N,N))
    allocate(revLen(1:2,1:2,N,N))
    allocate(Ham(2*N,2*N))
    allocate(S(2*N,2*N))
    allocate(E(2*N))

    if (letter == 'L') then
        !Считаем все необходимые матричные элементы на L-spinor'ах
        do k=1,N
            do l=1,N
            i = k-1
            j = l-1
            !Матрица неортогональности
            gram(1,1,k,l) = integrateOnGrid(lspinorVector(i, 'U'),lspinorVector(j, 'U'))
            !gram(1,2,i,j) = integrateOnGrid(lspinorVector(i, 'U'),lspinorVector(j, 'L'))
           ! gram(2,1,i,j) = integrateOnGrid(lspinorVector(i, 'L'),lspinorVector(j, 'U'))
            gram(2,2,k,l) = integrateOnGrid(lspinorVector(i, 'L'),lspinorVector(j, 'L'))
            !Матричный элемент потенциала
            V(1,1,k,l) = integrateOnGrid(lspinorVector(i,'U'), lspinorVectorWithFunc(VPot, j,'U'))
            !V(1,2,i,j) = integrateOnGrid(lspinorVector(i,'U'), lspinorVectorWithFunc(VPot, j,'L'))
            !V(2,1,i,j) = integrateOnGrid(lspinorVector(i,'L'), lspinorVectorWithFunc(VPot, j,'U'))
            V(2,2,k,l) = integrateOnGrid(lspinorVector(i,'L'), lspinorVectorWithFunc(VPot, j,'L'))
            !С 1/r
            !revLen(1,1,i,j) = integrateOnGrid(lspinorVector(i,'U'), lspinorVectorWithFunc(oneToX, j,'U'))
            revLen(1,2,k,l) = integrateOnGrid(lspinorVector(i,'U'), lspinorVectorWithFunc(oneToX, j,'L'))
            revLen(2,1,k,l) = integrateOnGrid(lspinorVector(i,'L'), lspinorVectorWithFunc(oneToX, j,'U'))
            !revLen(2,2,i,j) = integrateOnGrid(lspinorVector(i,'L'), lspinorVectorWithFunc(oneToX, j,'L'))
            !Производные
            !deriv(1,1,i,j) = integrateOnGrid(lspinorVector(i,'U'), lspinorDerivativeVector(j,'U'))
            deriv(1,2,k,l) = integrateOnGrid(lspinorVector(i,'U'), lspinorDerivativeVector(j,'L'))
            deriv(2,1,k,l) = integrateOnGrid(lspinorVector(i,'L'), lspinorDerivativeVector(j,'U'))
            !deriv(2,2,i,j) = integrateOnGrid(lspinorVector(i,'L'), lspinorDerivativeVector(j,'L'))
            end do
        end do
    else
        !Считаем все необходимые матричные элементы на полиномах Лагерра
        do k=1,N
            do l=1,N
            i = k-1
            j = l-1
            !Матрица неортогональности
            gram(1,1,k,l) = integrateOnGrid(lagVector(i, 'U'),lagVector(j, 'U'))
            !gram(1,2,i,j) = integrateOnGrid(lagVector(i, 'U'),lagVector(j, 'L'))
           ! gram(2,1,i,j) = integrateOnGrid(lagVector(i, 'L'),lagVector(j, 'U'))
            gram(2,2,k,l) = integrateOnGrid(lagVector(i, 'L'),lagVector(j, 'L'))
            !Матричный элемент потенциала
            V(1,1,k,l) = integrateOnGrid(lagVector(i,'U'), lagVectorWithFunc(VPot, j,'U'))
            !V(1,2,i,j) = integrateOnGrid(lagVector(i,'U'), lagVectorWithFunc(VPot, j,'L'))
            !V(2,1,i,j) = integrateOnGrid(lagVector(i,'L'), lagVectorWithFunc(VPot, j,'U'))
            V(2,2,k,l) = integrateOnGrid(lagVector(i,'L'), lagVectorWithFunc(VPot, j,'L'))
            !С 1/r
            !revLen(1,1,i,j) = integrateOnGrid(lagVector(i,'U'), lagVectorWithFunc(oneToX, j,'U'))
            revLen(1,2,k,l) = integrateOnGrid(lagVector(i,'U'), lagVectorWithFunc(oneToX, j,'L'))
            revLen(2,1,k,l) = integrateOnGrid(lagVector(i,'L'), lagVectorWithFunc(oneToX, j,'U'))
            !revLen(2,2,i,j) = integrateOnGrid(lagVector(i,'L'), lagVectorWithFunc(oneToX, j,'L'))
            !Производные
            !deriv(1,1,i,j) = integrateOnGrid(lagVector(i,'U'), lagDerivativeVector(j,'U'))
            deriv(1,2,k,l) = integrateOnGrid(lagVector(i,'U'), lagDerivativeVector(j,'L'))
            deriv(2,1,k,l) = integrateOnGrid(lagVector(i,'L'), lagDerivativeVector(j,'U'))
            !deriv(2,2,i,j) = integrateOnGrid(lagVector(i,'L'), lagDerivativeVector(j,'L'))
            end do
        end do
    end if
    !Костыль, не должно быть этого здесь
!    if (letter == 'L') then
!        do i=1,N
!            do j=1,N
!                deriv(1,2,i,j) = (deriv(1,2,i,j) - deriv(2,1,i,j))/2
!                deriv(2,1,j,i) = - deriv(1,2,i,j)
!            end do
!        end do
!    else
!        do i=1,N
!            do j=1,N
!                deriv(1,2,i,j) = (deriv(1,2,i,j) - deriv(1,2,j,i))/2
!                deriv(2,1,j,i) = deriv(1,2,i,j)
!            end do
!        end do
!    end if
    !Ham(1:N,1:N) = c**2 * gram(1,1,:,:) + V(1,1,:,:)
    Ham(1:N,1:N) = V(1,1,:,:)
    Ham(1:N,N+1:2*N) = -c * xScale *deriv(1,2,:,:) + c * kappa * revLen(1,2,:,:)
    Ham(N+1:2*N,1:N) = +c * xScale * deriv(2,1,:,:) + c * kappa * revLen(2,1,:,:)
    Ham(N+1:2*N,N+1:2*N) = - 2*c**2 * gram(2,2,:,:) + V(2,2,:,:)
    S(:,:) = 0;
    S(1:N,1:N) = gram(1,1,:,:)
    S(N+1:2*N,N+1:2*N) = gram(2,2,:,:)
    print *, "Derivatives, UL"
    call print4dimAs2(1,2,deriv)
    !print *, "Derivatives, UU"
    !call print4dimAs2(1,1,deriv)
    print *, "Derivatives, LU"
    call print4dimAs2(2,1,deriv)
    print *, "Hamiltonian"
    call print_r8(Ham, 1)
    print *,"S"
    call print_r8(S, 1)

    call general_eigvect_r8(Ham, S, E)

    !call print_r8(Ham)

    !E(:) = E(:) - c**2

    open(unit=19,file="basis.rez",status="replace")
    write(19,*) "kappa=",kappa," scale=",xScale, " Z=",Z, " basis Length=",N," basis type=",letter

    do i=2*N,N+1,-1
!        print *, "E=",E(i)," n=",Z/sqrt(-2*E(i))
        quantN = abs(kappa) + i - N - 1
        write(19, *) "E=",E(i), "right Energy=", rightEnergy(quantN, quantJ), &
        ' relative diff=',(E(i) - rightEnergy(quantN, quantJ))/abs(E(i))


        !0.5_WP*(1/quantN**2-1/c**2/quantN**3( 1/(0.5_WP + quantJ) - 0.75_WP/quantN ))
    end do
    close(19)

    deallocate(Ham)
    deallocate(S)
    deallocate(E)

    print *, "end"
!    print *, gram
    deallocate(gram)
    deallocate(V)
    deallocate(deriv)
    deallocate(revLen)
!    !Проверка ортогональности полиномов Лагерра
!    call setGlobalParameters(N - 1, 0.0_WP, 0.0_WP, qLen, x)
!    do k = 0, N -1
!        do j = 0,N - 1
!            summa=0.0_WP
!            do i=1,qLen
!                summa = summa + w(i)*laguerrePoly(i, k)*laguerrePoly(i, j)
!            end do
!            print *, "j=",j,"k=",k," rez=",summa
!        end do
!        print * , ""
!    end do
    deallocate(x)
end program
