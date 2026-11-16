INCLUDE Irvine32.inc


MAX_PRODUCTOS EQU 10
; ----------------------------------------------------------------
; Define la estructura de cada videojuego: codigo, nombre, precio y existencias.
; ----------------------------------------------------------------
PRODUCTO STRUCT
  codigo BYTE 8 DUP(0)
  nombre BYTE 26 DUP(0)
  precio DWORD 0
  existencias DWORD 0
PRODUCTO ENDS



; Secuencias cortas: MASM las expande en cada punto de uso.
mTexto MACRO texto
    mov edx, OFFSET texto
    call MostrarTexto
ENDM

mCampoEntero MACRO etiqueta, valor
    mTexto etiqueta
    mov eax, valor
    call MostrarEntero
ENDM

mAlertaStock MACRO unidades
    LOCAL sinAlerta
    cmp unidades, 5
    ja sinAlerta
    mTexto avisoPocasExistencias
sinAlerta:
ENDM

mOpcion MACRO tecla, rutina
    LOCAL siguienteOpcion
    cmp al, tecla
    jne siguienteOpcion
    call rutina
    jmp cicloMenu
siguienteOpcion:
ENDM

.data
menuPrincipal BYTE 13,10,'=== TIENDA GameStop ===',13,10,'1.- Registrar Producto ',13,10,'2.- Mostrar Inventario ',13,10,'3.- Buscar Articulo ',13,10,'4.- Recibir Mercancia',13,10,'5.- Vender',13,10,'6.- Resumen de Movimientos ',13,10,'7.- Guardar Catalogo',13,10,'8.- Cargar Catalogo',13,10,'0.- Salir',13,10,'Opcion: ',0
pedirCodigo BYTE 'Codigo (ej: ABC-123): ',0
pedirNombre BYTE 'Nombre (1-25): ',0
pedirPrecio BYTE 'Precio MXN: ',0
pedirExistencias BYTE 'Existencia (0-100): ',0
pedirCantidad BYTE 'Cantidad (>0): ',0
mensajeInvalido BYTE 'Dato invalido o fuera de rango.',13,10,0
mensajeNoEncontrado BYTE 'Producto no encontrado.',13,10,0
mensajeDuplicado BYTE 'Codigo duplicado.',13,10,0
mensajeLleno BYTE 'Capacidad de 10 productos alcanzada.',13,10,0
mensajeExito BYTE 'Operacion realizada.',13,10,0
mensajeSinExistencias BYTE 'Existencia insuficiente o limite excedido.',13,10,0
mensajeErrorArchivo BYTE 'Error de archivo o datos invalidos. Catalogo conservado.',13,10,0
mensajeGuardado BYTE 'Catalogo guardado.',13,10,0
mensajeCargado BYTE 'Catalogo cargado.',13,10,0
avisoCambios BYTE 'Hay cambios sin guardar. Salir? (S/N): ',0
avisoPocasExistencias BYTE ' *** ALERTA: existencia minima ***',0
etiquetaCodigo BYTE 'Codigo: ',0
etiquetaNombre BYTE '  Nombre: ',0
etiquetaPrecio BYTE '  Precio: ',0
etiquetaExistencias BYTE '  Unidades: ',0
etiquetaUnidades BYTE 'Unidades disponibles: ',0
etiquetaValor BYTE 'Valor inventario: ',0
etiquetaIngresos BYTE 'Ingresos de esta sesion: ',0
etiquetaVenta BYTE 'Importe de venta: ',0
textoMXN BYTE ' MXN',13,10,0
nombreArchivo BYTE 'inventario.dat',0
entrada BYTE 128 DUP(0)
bufferNumero BYTE 16 DUP(0)

; ----------------------------------------------------------------
; Arreglo de hasta diez registros PRODUCTO, almacenados consecutivamente.
; ----------------------------------------------------------------
catalogo PRODUCTO MAX_PRODUCTOS DUP(<>)
temporal PRODUCTO MAX_PRODUCTOS DUP(<>)
cantidadProductos DWORD 0
cantidadNueva DWORD 0

; ----------------------------------------------------------------
; Acumula el dinero cobrado durante esta sesion, expresado en centavos.
; ----------------------------------------------------------------
ingresos DWORD 0
cambiosPendientes BYTE 0
manejadorArchivo DWORD 0
cabeceraArchivo DWORD 324E5649h
cantidadArchivo DWORD 0

; ----------------------------------------------------------------
; Espacio para la cabecera, cantidad de registros y productos del archivo binario.
; ----------------------------------------------------------------
bufferArchivo BYTE (9+MAX_PRODUCTOS*SIZEOF PRODUCTO) DUP(0)


.code
CopiarBytes PROC USES ecx esi edi
    cld
    rep movsb
    ret
CopiarBytes ENDP

LimpiarBytes PROC USES eax ecx edi
    xor eax, eax
    cld
    rep stosb
    ret
LimpiarBytes ENDP

CodigosIguales PROC USES ecx esi edi
    mov ecx, 7
compararSiete:
    mov al, [esi]
    cmp al, [edi]
    jne codigosDiferentes
    inc esi
    inc edi
    loop compararSiete
    mov eax, 1
    ret
codigosDiferentes:
    xor eax, eax
    ret
CodigosIguales ENDP

EncontrarEnBloque PROC USES ebx ecx edx esi edi
    mov edi, edx
    xor ebx, ebx
buscarEnBloque:
    test ecx, ecx
    jz bloqueSinCodigo
    call CodigosIguales
    test eax, eax
    jnz bloqueConCodigo
    add esi, SIZEOF PRODUCTO
    inc ebx
    dec ecx
    jmp buscarEnBloque
bloqueConCodigo:
    mov eax, ebx
    ret
bloqueSinCodigo:
    mov eax, -1
    ret
EncontrarEnBloque ENDP

CalcularImporte PROC USES edx
    mul ecx
    test edx, edx
    jnz importeDesbordado
    clc
    ret
importeDesbordado:
    stc
    ret
CalcularImporte ENDP

ValidarRegistroProducto PROC USES ecx edx edi
    lea edx, [esi].PRODUCTO.codigo
    cmp BYTE PTR [edx+7], 0
    jne registroInvalido
    call ValidarCodigo
    test eax, eax
    jz registroInvalido
    lea edi, [esi].PRODUCTO.nombre
    xor ecx, ecx
medirNombreRegistro:
    cmp ecx, 26
    jae registroInvalido
    cmp BYTE PTR [edi+ecx], 0
    je comprobarNombreRegistro
    inc ecx
    jmp medirNombreRegistro
comprobarNombreRegistro:
    cmp ecx, 1
    jb registroInvalido
    cmp ecx, 25
    ja registroInvalido
    cmp DWORD PTR [esi].PRODUCTO.precio, 1
    jb registroInvalido
    cmp DWORD PTR [esi].PRODUCTO.precio, 999999
    ja registroInvalido
    cmp DWORD PTR [esi].PRODUCTO.existencias, 100
    ja registroInvalido
    mov eax, 1
    ret
registroInvalido:
    xor eax, eax
    ret
ValidarRegistroProducto ENDP

MostrarTexto PROC USES eax ecx edx
 call WriteString
 ret

MostrarTexto ENDP

PedirTexto PROC USES ecx edx
 call WriteString
 mov edx,OFFSET entrada
 mov ecx,SIZEOF entrada-1
 call ReadString
 ret

PedirTexto ENDP


; ----------------------------------------------------------------
; Convierte una cadena de digitos ASCII a un entero sin ReadDec.
; ----------------------------------------------------------------

ConvertirEntero PROC USES ebx ecx edx esi edi
 mov esi,edx
 test ecx,ecx
 jz enteroInvalido

 xor edi,edi

cicloEntero:
 movzx ebx,BYTE PTR [esi]
 cmp ebx,'0'
 jb enteroInvalido

 cmp ebx,'9'
 ja enteroInvalido

 sub ebx,'0'
 mov eax,edi
 mov edx,10
 mul edx
 test edx,edx
 jnz enteroInvalido

 add eax,ebx
 jc enteroInvalido

 mov edi,eax
 inc esi
 dec ecx
 jnz cicloEntero

 mov eax,edi
 clc
 ret


enteroInvalido:
 stc
 ret

ConvertirEntero ENDP


; ----------------------------------------------------------------
; Convierte un precio decimal escrito como texto a centavos enteros.
; ----------------------------------------------------------------
ConvertirPrecio PROC USES ebx ecx edx esi edi ebp
 mov esi,edx
 test ecx,ecx
 jz precioInvalido

 xor edi,edi
 xor ebp,ebp
 xor ebx,ebx

cicloPrecio:
 movzx eax,BYTE PTR [esi]
 cmp al,'.'
 je puntoDecimal

 cmp al,'0'
 jb precioInvalido

 cmp al,'9'
 ja precioInvalido

 sub eax,'0'
 cmp ebp,0
 jne digitoDecimal

 inc ebx
 cmp edi,9999
 ja precioInvalido

 imul edi,edi,10
 add edi,eax
 cmp edi,9999
 ja precioInvalido

 jmp siguientePrecio


digitoDecimal:
 cmp ebp,3
 jae precioInvalido

 imul edi,edi,10
 add edi,eax
 inc ebp
 jmp siguientePrecio


puntoDecimal:
 test ebx,ebx
 jz precioInvalido

 test ebp,ebp
 jnz precioInvalido

 mov ebp,1

siguientePrecio:
 inc esi
 dec ecx
 jnz cicloPrecio

 test ebx,ebx
 jz precioInvalido

 cmp ebp,1
 je precioInvalido

 cmp ebp,0
 jne comprobarPrecio

 imul edi,edi,100
 jmp comprobarPrecio


comprobarPrecio:
 cmp ebp,2
 jne limitePrecio

 imul edi,edi,10

limitePrecio:
 cmp edi,1
 jb precioInvalido

 cmp edi,999999
 ja precioInvalido

 ; Resultado convertido a centavos devuelto en EAX.
 mov eax,edi
 clc
 ret


precioInvalido:
 stc
 ret

ConvertirPrecio ENDP


; ----------------------------------------------------------------
; Solicita texto, lo convierte a entero y valida minimo (EDI) y maximo (EBX).
; ----------------------------------------------------------------

LeerEntero PROC USES ebx ecx edx esi edi
 call PedirTexto
 mov edx,OFFSET entrada
 mov ecx,eax
 call ConvertirEntero
 jc lecturaInvalida

 cmp eax,edi
 jb lecturaInvalida

 cmp eax,ebx
 ja lecturaInvalida

 clc
 ret


lecturaInvalida:
 mTexto mensajeInvalido
 stc
 ret

LeerEntero ENDP


; ----------------------------------------------------------------
; Lee el precio y delega su conversion a ConvertirPrecio.
; ----------------------------------------------------------------
LeerPrecio PROC USES ecx edx
 mov edx,OFFSET pedirPrecio
 call PedirTexto
 mov edx,OFFSET entrada
 mov ecx,eax
 call ConvertirPrecio
 jnc precioLeido

 mTexto mensajeInvalido
 stc

precioLeido:
 ret

LeerPrecio ENDP


; ----------------------------------------------------------------
; Comprueba el formato de codigo ABC-123.
; ----------------------------------------------------------------
ValidarCodigo PROC USES ecx esi
 mov esi,edx
 mov ecx,3

validarLetras:
 mov al,[esi]
 cmp al,'A'
 jb codigoInvalido

 cmp al,'Z'
 ja codigoInvalido

 inc esi
 loop validarLetras

 cmp BYTE PTR [esi],'-'
 jne codigoInvalido

 inc esi
 mov ecx,3

validarDigitos:
 mov al,[esi]
 cmp al,'0'
 jb codigoInvalido

 cmp al,'9'
 ja codigoInvalido

 inc esi
 loop validarDigitos

 cmp BYTE PTR [esi],0
 jne codigoInvalido

 mov eax,1
 ret


codigoInvalido:
 xor eax,eax
 ret

ValidarCodigo ENDP


; ----------------------------------------------------------------
; Recorre el catalogo con ESI comparando los codigos.
; ----------------------------------------------------------------
EncontrarCodigo PROC USES ecx esi
    mov esi, OFFSET catalogo
    mov ecx, cantidadProductos
    call EncontrarEnBloque
    ret
EncontrarCodigo ENDP


; ----------------------------------------------------------------
; Solicita un codigo y comprueba longitud y formato.
; ----------------------------------------------------------------
LeerCodigo PROC USES edx
 mov edx,OFFSET pedirCodigo
 call PedirTexto
 cmp eax,7
 jne capturaCodigoInvalida

 mov edx,OFFSET entrada
 call ValidarCodigo
 test eax,eax
 jz capturaCodigoInvalida

 mov eax,7
 clc
 ret


capturaCodigoInvalida:
 mTexto mensajeInvalido
 stc
 ret

LeerCodigo ENDP


; ----------------------------------------------------------------
; Convierte un entero a caracteres decimales mediante divisiones entre diez.
; ----------------------------------------------------------------
MostrarEntero PROC USES eax ebx ecx edx esi
 mov esi,OFFSET bufferNumero+15
 mov BYTE PTR [esi],0
 mov ebx,10

extraerDigito:
 xor edx,edx
 div ebx
 add dl,'0'
 dec esi
 mov [esi],dl
 test eax,eax
 jnz extraerDigito

 mov edx,esi
 call MostrarTexto
 ret

MostrarEntero ENDP


; ----------------------------------------------------------------
; Separa pesos y centavos para mostrar importes con dos decimales.
; ----------------------------------------------------------------
MostrarPrecio PROC USES eax ebx edx
 xor edx,edx
 mov ebx,100
 ; Cociente: pesos; residuo en EDX: centavos.
 div ebx
 push edx
 call MostrarEntero
 mov al,'.'
 call WriteChar
 pop eax
 cmp eax,10
 jae dosDecimales

 push eax
 mov al,'0'
 call WriteChar
 pop eax

dosDecimales:
 call MostrarEntero
 mTexto textoMXN
 ret

MostrarPrecio ENDP


; ----------------------------------------------------------------
; Imprime los datos de un producto apuntado por ESI.
; ----------------------------------------------------------------
MostrarProducto PROC USES eax edx
 mTexto etiquetaCodigo
 mov edx,esi
 call MostrarTexto
 mTexto etiquetaNombre
 lea edx,[esi].PRODUCTO.nombre
 call MostrarTexto
 call Crlf
 mTexto etiquetaPrecio
 mov eax,[esi].PRODUCTO.precio
 call MostrarPrecio
 mCampoEntero etiquetaExistencias, [esi].PRODUCTO.existencias
 mAlertaStock DWORD PTR [esi].PRODUCTO.existencias
 call Crlf
 ret

MostrarProducto ENDP


; ----------------------------------------------------------------
; Recorre todos los productos y los imprime.
; ----------------------------------------------------------------
MostrarInventario PROC USES eax ecx esi
 ; ESI apunta al primer registro del catalogo.
 mov esi,OFFSET catalogo
 mov ecx,cantidadProductos
 test ecx,ecx
 jz finInventario


cicloInventario:
 call MostrarProducto
 ; Avanza ESI al siguiente producto de la estructura.
 add esi,SIZEOF PRODUCTO
 loop cicloInventario


finInventario:
 ret

MostrarInventario ENDP


; ----------------------------------------------------------------
; Valida y registra un videojuego sin permitir codigos repetidos.
; ----------------------------------------------------------------
RegistrarProducto PROC USES eax ebx ecx edx esi edi
 cmp cantidadProductos,MAX_PRODUCTOS
 jae altaLlena

 call LeerCodigo
 jc finAlta

 mov edx,OFFSET entrada
 call EncontrarCodigo
 cmp eax,-1
 jne altaDuplicada

 mov esi,OFFSET temporal
 mov edi,esi
 mov ecx,SIZEOF PRODUCTO
 call LimpiarBytes
 mov edi,esi
 mov esi,OFFSET entrada
 mov ecx,7

 call CopiarBytes
 mov edx,OFFSET pedirNombre
 call PedirTexto
 cmp eax,1
 jb altaInvalida

 cmp eax,25
 ja altaInvalida

 mov ecx,eax
 mov esi,OFFSET entrada
 mov edi,OFFSET temporal.nombre

 call CopiarBytes
 call LeerPrecio
 jc finAlta

 mov temporal.precio,eax
 mov edx,OFFSET pedirExistencias
 mov ebx,100
 xor edi,edi
 call LeerEntero
 jc finAlta

 mov temporal.existencias,eax
 mov eax,cantidadProductos
 imul eax,SIZEOF PRODUCTO
 lea edi,catalogo[eax]
 mov esi,OFFSET temporal
 mov ecx,SIZEOF PRODUCTO

 call CopiarBytes
 inc cantidadProductos
 mov cambiosPendientes,1
 jmp altaExitosa


altaLlena:
 mov edx,OFFSET mensajeLleno
 jmp mostrarAlta


altaDuplicada:
 mov edx,OFFSET mensajeDuplicado
 jmp mostrarAlta


altaInvalida:
 mov edx,OFFSET mensajeInvalido
 jmp mostrarAlta


altaExitosa:
 mov edx,OFFSET mensajeExito

mostrarAlta:
 call MostrarTexto

finAlta:
 ret

RegistrarProducto ENDP


; ----------------------------------------------------------------
; Pide un codigo y devuelve en ESI la direccion del producto encontrado.
; ----------------------------------------------------------------
LocalizarProducto PROC USES eax edx
 call LeerCodigo
 jc localizacionInvalida

 mov edx,OFFSET entrada
 call EncontrarCodigo
 cmp eax,-1
 je productoNoExiste

 imul eax,SIZEOF PRODUCTO
 lea esi,catalogo[eax]
 clc
 ret


productoNoExiste:
 mTexto mensajeNoEncontrado

localizacionInvalida:
 stc
 ret

LocalizarProducto ENDP


; ----------------------------------------------------------------
; Busca un producto y muestra su informacion.
; ----------------------------------------------------------------
BuscarProducto PROC USES esi
 call LocalizarProducto
 jc finBusqueda

 call MostrarProducto

finBusqueda:
 ret

BuscarProducto ENDP


; ----------------------------------------------------------------
; Aumenta existencias de un producto, respetando el maximo de 100.
; ----------------------------------------------------------------
RecibirMercancia PROC USES eax ebx edx edi esi
 call LocalizarProducto
 jc finRecepcion

 mov edx,OFFSET pedirCantidad
 mov ebx,100
 mov edi,1
 call LeerEntero
 jc finRecepcion

 mov ebx,[esi].PRODUCTO.existencias
 ; Suma las unidades recibidas a las existencias actuales.
 add ebx,eax
 cmp ebx,100
 ja recepcionExcesiva

 mov [esi].PRODUCTO.existencias,ebx
 mov cambiosPendientes,1
 mov edx,OFFSET mensajeExito
 jmp mostrarRecepcion


recepcionExcesiva:
 mov edx,OFFSET mensajeSinExistencias

mostrarRecepcion:
 call MostrarTexto

finRecepcion:
 ret

RecibirMercancia ENDP


; ----------------------------------------------------------------
; Valida existencias, calcula venta sin ofertas y actualiza ingresos.
; ----------------------------------------------------------------
 VenderProducto PROC USES eax ebx ecx edx edi esi
 call LocalizarProducto
 jc finVenta

 mCampoEntero etiquetaExistencias, [esi].PRODUCTO.existencias
 call Crlf

 mov edx,OFFSET pedirCantidad
 mov ebx,100
 mov edi,1
 call LeerEntero
 jc finVenta

 mov ecx,eax
 cmp ecx,[esi].PRODUCTO.existencias
 ja ventaRechazada

 ; Precio unitario en centavos para calcular el importe de venta.
 mov eax,[esi].PRODUCTO.precio
 ; Multiplica el precio unitario por la cantidad vendida.
 call CalcularImporte
 jc ventaRechazada
 ; EAX contiene el importe total de la venta sin descuentos.
 mov ebx,eax
 mov edx,ingresos
 add edx,ebx
 jc ventaRechazada

 ; IMPORTANTE: guardar el acumulado ANTES de reutilizar EDX para textos.
 ; En la version anterior se guardaba la direccion de etiquetaUnidades.
 mov ingresos,edx

 ; Restar unidades vendidas del inventario.
 sub [esi].PRODUCTO.existencias,ecx
 mov cambiosPendientes,1

 ; Mostrar cuantas unidades quedaron.
 call Crlf
 mCampoEntero etiquetaUnidades, [esi].PRODUCTO.existencias
 call Crlf

 ; Mostrar el total cobrado en esta venta (centavos -> pesos).
 mTexto etiquetaVenta
 mov eax,ebx
 call MostrarPrecio
 jmp finVenta


ventaRechazada:
 mTexto mensajeSinExistencias

finVenta:
 ret

VenderProducto ENDP


; ----------------------------------------------------------------
; Suma unidades disponibles y valor total del inventario; muestra ingresos.
; ----------------------------------------------------------------
MostrarResumen PROC USES eax ebx ecx edx esi edi
 xor edi,edi
 xor ebx,ebx
 ; ESI apunta al primer registro del catalogo.
 mov esi,OFFSET catalogo
 mov ecx,cantidadProductos

cicloResumen:
 test ecx,ecx
 jz imprimirResumen

 push edx
 lea edx, [esi].PRODUCTO.nombre
 call MostrarTexto
 mCampoEntero etiquetaExistencias, [esi].PRODUCTO.existencias
 call Crlf
 pop edx

 add edi,[esi].PRODUCTO.existencias
 mov eax,[esi].PRODUCTO.precio
 ; EAX = precio en centavos * unidades existentes (valor del producto).
 push ecx
 mov ecx,[esi].PRODUCTO.existencias
 call CalcularImporte
 pop ecx
 ; Acumula el valor de este producto en el total del inventario.
 add ebx,eax
 ; Avanza ESI al siguiente producto de la estructura.
 add esi,SIZEOF PRODUCTO
 dec ecx
 jmp cicloResumen


imprimirResumen:
 mCampoEntero etiquetaUnidades, edi
 call Crlf
 mTexto etiquetaValor
 mov eax,ebx
 call MostrarPrecio
 mTexto etiquetaIngresos
 ; Recupera el acumulado real de ventas de la sesion.
 mov eax,ingresos
 call MostrarPrecio
 ret

MostrarResumen ENDP


; ----------------------------------------------------------------
; Escribe la cabecera y registros en inventario.dat en formato binario.
; ----------------------------------------------------------------
GuardarInventario PROC USES eax ecx edx esi edi
 mov cantidadArchivo,0
 mov eax,cantidadProductos
 mov cantidadArchivo,eax
 cld
 mov edi,OFFSET bufferArchivo
 mov eax,cabeceraArchivo
 stosd
 mov eax,cantidadProductos
 stosd
 ; ESI apunta al primer registro del catalogo.
 mov esi,OFFSET catalogo
 mov ecx,cantidadProductos
 imul ecx,SIZEOF PRODUCTO

 call CopiarBytes
 mov edx,OFFSET nombreArchivo
 call CreateOutputFile
 cmp eax,INVALID_HANDLE_VALUE
 je errorGuardado

 mov manejadorArchivo,eax
 mov edx,OFFSET bufferArchivo
 mov ecx,cantidadProductos
 imul ecx,SIZEOF PRODUCTO
 add ecx,8
 push ecx
 call WriteToFile
 pop ecx
 jc errorCerrarGuardado
 cmp eax,ecx
 jne errorCerrarGuardado

 mov eax,manejadorArchivo
 call CloseFile
 mov cambiosPendientes,0
 mTexto mensajeGuardado
 ret


errorCerrarGuardado:
 mov eax,manejadorArchivo
 call CloseFile

errorGuardado:
 mTexto mensajeErrorArchivo
 ret

GuardarInventario ENDP


; ----------------------------------------------------------------
; Lee y valida el archivo binario antes de reemplazar el catalogo.
; ----------------------------------------------------------------
CargarInventario PROC USES eax ebx ecx edx esi edi ebp
 mov edx,OFFSET nombreArchivo
 call OpenInputFile
 cmp eax,INVALID_HANDLE_VALUE
 je errorCarga

 mov manejadorArchivo,eax
 mov edx,OFFSET bufferArchivo
 mov ecx,SIZEOF bufferArchivo
 call ReadFromFile
 jc errorCerrarCarga

 mov ebp,eax
 mov eax,manejadorArchivo
 call CloseFile
 cmp ebp,8
 jb errorCarga

 cmp DWORD PTR bufferArchivo,324E5649h
 jne errorCarga

 mov eax,DWORD PTR bufferArchivo+4
 cmp eax,MAX_PRODUCTOS
 ja errorCarga

 mov cantidadNueva,eax
 imul eax,SIZEOF PRODUCTO
 add eax,8
 cmp eax,ebp
 jne errorCarga

 mov esi,OFFSET bufferArchivo+8
 xor ebx,ebx

validarRegistro:
 cmp ebx,cantidadNueva
 jae confirmarCarga

 call ValidarRegistroProducto
 test eax,eax
 jz errorCarga

 ; Buscar el codigo solamente entre los registros anteriores.
 push esi
 lea edx,[esi].PRODUCTO.codigo
 mov esi,OFFSET bufferArchivo+8
 mov ecx,ebx
 call EncontrarEnBloque
 pop esi
 cmp eax,-1
 jne errorCarga

 add esi,SIZEOF PRODUCTO
 inc ebx
 jmp validarRegistro

confirmarCarga:
 mov esi,OFFSET bufferArchivo+8
 mov edi,OFFSET catalogo
 mov ecx,cantidadNueva
 imul ecx,SIZEOF PRODUCTO

 call CopiarBytes
 mov eax,cantidadNueva
 mov cantidadProductos,eax
 ; Al cargar el catalogo, los ingresos de la sesion vuelven a cero.
 mov ingresos,0
 mov cambiosPendientes,0
 mTexto mensajeCargado
 ret


errorCerrarCarga:
 mov eax,manejadorArchivo
 call CloseFile

errorCarga:
 mTexto mensajeErrorArchivo
 ret

CargarInventario ENDP


; ----------------------------------------------------------------
; Punto de entrada: carga catalogo y procesa el menu.
; ----------------------------------------------------------------
main PROC

; 1. Cargar inventario de la sesión anterior 
  call CargarInventario

cicloMenu:
  mov edx,OFFSET menuPrincipal
  call PedirTexto
  cmp eax,1
  jne opcionInvalida

  mov al,entrada
  cmp al,'0'
  je opcionSalir
  mOpcion '1', RegistrarProducto
  mOpcion '2', MostrarInventario
  mOpcion '3', BuscarProducto
  mOpcion '4', RecibirMercancia
  mOpcion '5', VenderProducto
  mOpcion '6', MostrarResumen
  mOpcion '7', GuardarInventario
  mOpcion '8', CargarInventario

opcionInvalida:
  mTexto mensajeInvalido
  jmp cicloMenu

opcionSalir:
  cmp cambiosPendientes,0
  je mainEnd

  mov edx,OFFSET avisoCambios
  call PedirTexto
  cmp eax,1
  jne cicloMenu

  mov al,entrada
  cmp al,'S'
  je guardarAlSalir
  cmp al,'s'
  je guardarAlSalir
  jmp mainEnd       ; Si presiona N u otra cosa, sale sin guardar

guardarAlSalir:
  call GuardarInventario

mainEnd:
  exit

main ENDP
END main