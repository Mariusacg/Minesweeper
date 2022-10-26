.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Minesweeper de buget",0
area_width EQU 640
area_height EQU 520
area DD 0



counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20


symbol_width EQU 40
symbol_height EQU 40
include digits.inc
include letters.inc


;;;variabile -minesweeper

sirnr db 192 dup(0)
matricea db 192 dup(0)
k dd 0
indice_lini dd 0
indice_coloane dd 0
msg1 db "%d    " ,0
msg2 db " " ,10,0
verf db 0
contor db 0

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
initializare macro sir,dimensiune,nr
local reia
    mov k,0 
    mov esi,0 
	reia:            
	mov sir[esi],nr
	inc esi
	inc k
	cmp k,dimensiune
    jne reia

endm
generare_random macro sir,dimensiune_plus_1,nr_generate
local reia
    reia:
	
    rdtsc             ;;;;generarea unui numar random 0-192 pentru matrice
	mov edx,0
    mov ebx,eax
    rdtsc
    mov edx,0
    add eax,ebx	
	mov ebx,eax
	rdtsc
	mov edx,0
	add eax,ebx
	mov ebx,dimensiune_plus_1
	div ebx	  	          ;;;;
	
	
	cmp sir[edx], 1   ;verificam daca a mai fost odata ales acelasi numar
	je reia
	inc sir[edx]
	
    inc k           ;reluam procesul de 35 de ori-35 de mine
	cmp k,nr_generate       
	jne reia
	

endm
afisare_matrice_consola macro sir,dimensiune
local reia,afisare

    mov k,dimensiune   
	mov esi,0
	
	afisare:
	mov eax,0
	mov al,sir[esi]
	push eax
	push offset msg1
	call printf
	add esp,8
	
	mov eax,esi   ;;aflarea pozitiei in matrice
    mov edx,0 	
	mov ebx,16
	div ebx
	cmp edx,15
	jne  reia
    push offset msg2
	call printf
	add esp,4
    reia:
	
	inc esi
	mov ecx ,k
	dec k
	loop afisare 
endm
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat

	sub eax, '0'
	lea esi, digits
	
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height     ;mici modificari pentru a accepta dd in loc de dd in digits.inc
	mul ebx
	push eax
    shl eax ,2
	add esi, eax
	mov ecx, symbol_height
	pop eax
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:

	mov ebx, [esi]
	mov dword ptr [edi], ebx

	add esi,4
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_matrice
	
evt_click: 

	cmp verf,0
	jg afisare_mesaje_victorie_infrangere
	cmp contor,157
	je afisare_mesaje_victorie_infrangere
	
	mov eax ,[ebp+arg3]  ;;;;lini
	;mov ebx ,[ebp+arg2]  ;;;;coloane
    cmp eax,479
    jg easteregg
	
    mov edx,0
	mov ebx,40
    div ebx
    mov ebx,16    
    mul ebx
	mov ecx,eax            ;;determin in ce patratel din matrice s-a dat click
    mov eax ,[ebp+arg2]
	mov ebx,40
	mov edx,0
	div ebx
    add eax,ecx   

	
	cmp sirnr[eax],1       
	je afisare_matrice
	mov sirnr[eax],1     ;;in noua matrice dezvalui patratelul pe care s-a dat click
	push eax
	cmp matricea[eax],0
	jne continuare
	
  	mov ecx,1
	push eax
	coincidenta:    ;;;un fel de recursivitate pentru pozitiile care au 0 mine una langa alta
	cmp ecx,0
	je continuare
    pop esi  
	
	
	
	
	mov eax,esi   ;;aflarea pozitiei in matrice
    mov edx,0 	
	mov ebx,16    ;; edx- coloana eax-linia
	div ebx
	
	cmp edx,0                           
	je  nu9                      
    cmp sirnr[esi-1] ,1
	je nu9
	cmp matricea[esi-1] ,0            ;fil-for de buget
	jne nu9
	inc sirnr[esi-1]
	mov k,esi
	dec k
	push k
	inc ecx
	inc contor
   
    nu9:	
	cmp edx,15
	je  nu19
    cmp sirnr[esi+1] ,1
	je nu19
    cmp matricea[esi+1] ,0
	jne nu19
	inc sirnr[esi+1]
	mov k,esi
	inc k
	push k
	inc ecx
	inc contor
  
    nu19:
	
	
    cmp eax,0
	je  sari59
	cmp sirnr[esi-16] ,1
	je sari59
    cmp matricea[esi-16] ,0
	jne sari59
	inc sirnr[esi-16]
	mov k,esi
	sub k,16
	push k
	inc ecx
	inc contor
	
	
    sari59:
    cmp eax,11
	je  sari9
    cmp sirnr[esi+16] ,1
	je sari9
    cmp matricea[esi+16] ,0
	jne sari9
	inc sirnr[esi+16]
	mov k,esi
	add k,16
	push k
	inc ecx	
	inc contor
	
	sari9:
	
	
	
	dec ecx
	jmp coincidenta
	continuare:
	pop eax
	inc contor
	cmp contor,157
	je over
	cmp matricea[eax],10   ;;daca era 10(mina) intrementez verf care daca este 1(sau mai mult) se va da semnalul de game over
	jne afisare_matrice
	inc verf
	jmp over
	
	easteregg:              ;
	mov edi, area           ;
	mov ecx, area_height    ;
	mov ebx, [ebp+arg3]     ;
	and ebx, 7              ;
	inc ebx                 ;
bucla_linii:                ;
	mov eax, [ebp+arg2]     ;
	and eax, 0FFh                       ; ramasite
	mul eax                 ;
	mul eax                 ;
	add eax, ecx            ;
	push ecx                ;
	mov ecx, area_width     ;
bucla_coloane:              ;
	mov [edi], eax          ;
	add edi, 4              ;
	add eax, ebx            ;
	loop bucla_coloane      ;
	pop ecx                 ;
	loop bucla_linii        ;
	jmp afisare_matrice     ;
	
	
	over:
	
	initializare sirnr,192,1            ;sirnr-ul devine 1 astfel se va afisa toata mapa la finalul jocului
	
	
	jmp afisare_matrice
	
evt_timer:
	inc counter
	
	cmp verf,0
	jg afisare_mesaje_victorie_infrangere
	cmp contor,157
	je afisare_mesaje_victorie_infrangere
	
afisare_matrice:

    mov k,0
	mov indice_lini,0
	mov indice_coloane,0     ;;afisez 192 de patratele(de 40*40) in functie de matricea sirnr care tine evidenta daca s-a apasat pe patratelul respectiv sau nu
	mov esi,0                ;;in matricea "matricea" am generat deja toata mapa de joc cu bombele si pentru fiecare locatie numarul de bombe alaturate
	reia4:           
	cmp sirnr[esi],1
	je neaf
	push esi
	make_text_macro '9', area,indice_coloane,indice_lini
	pop esi
    jmp incrementari	
	neaf:
	mov eax,0
	mov al,matricea[esi]
	add eax,'0'
	make_text_macro eax,area,indice_coloane,indice_lini
	
	
	incrementari:
	add indice_coloane, 40             ;;controlez indici in functie de dimensiunile prestabilite alea arii de desenat
	cmp indice_coloane,640
	jne ramane
	add indice_lini ,40
	mov indice_coloane,0
	ramane:
	inc esi
	inc k
	cmp k,192
    jne reia4
	
	mov eax,'9'
    add eax,10                               ;  ":)"
	make_text_macro eax, area, 120, 480	
	
	                           ;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 340, 480
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 300, 480
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 260, 480
	
	jmp final_draw
	
afisare_mesaje_victorie_infrangere:     
    cmp contor,157
	jne infrangere                        ;;;mesajul la victorie-bifa
	mov eax, '9'
    add eax,8
	make_text_macro eax, area, 400, 480	
	mov eax, '9'
    add eax,9
	make_text_macro eax, area, 120, 480	 
	jmp final_draw 
	
	infrangere:  

    mov eax, '9'
    add eax,2
    make_text_macro eax, area, 200, 200	
    mov eax, '9'
    add eax,3
	make_text_macro eax, area, 240, 200	       ;;;mesajul de game over "wasted"
	mov eax, '9'
    add eax,4
	make_text_macro eax, area, 280, 200	
	mov eax, '9'
    add eax,5
	make_text_macro eax, area, 320, 200	
	mov eax, '9'
    add eax,6
	make_text_macro eax, area, 360, 200	
	mov eax, '9'
    add eax,7
	make_text_macro eax, area, 400, 200	
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
   
    generare_random sirnr,193,35
	
	
	mov k,0      ;;;;creez o matrice noua care sa aiba pe fiecare pozitie numarul de bombe alaturate 
	mov esi,0 
	
	reia2:
	
	cmp sirnr[esi] ,0
	je sari
	mov matricea[esi],10    ;; daca are 10 este bomba
	
	mov eax,esi   ;;aflarea pozitiei in matrice
    mov edx,0 	
	mov ebx,16    ;; edx- coloana eax-linia
	div ebx
	
	cmp edx,0                   ;; verificari daca pozitia gasita este pe una dintre marginile matricii
	je  nu                      ;; deasemnea incrementez pentru fiecare bomba gasita toti vecini din noua matrice
    cmp sirnr[esi-1] ,1
	je sari1
	inc matricea[esi-1]
	
	sari1:
	cmp eax,0
	je  sari2
	cmp sirnr[esi-17] ,1
	je sari2
    inc matricea[esi-17]
    sari2:
    cmp eax,11
	je  nu
    inc matricea[esi+15]                   ;;;;         +1     +1     +1
                                           ;;;;         +1  bomba=10  +1   
    nu:	                                   ;;;;         +1     +1     +1
	cmp edx,15
	je  nu1
    inc matricea[esi+1]
	cmp eax,0
	je  sari3
	cmp sirnr[esi-15] ,1
	je sari3
    inc matricea[esi-15]
    sari3:
    cmp eax,11
	je  nu1
    inc matricea[esi+17]
  
    nu1:
	
	
    cmp eax,0
	je  sari4
	cmp sirnr[esi-16] ,1
	je sari4
    inc matricea[esi-16]
    sari4:
    cmp eax,11
	je  sari
    inc matricea[esi+16]		
	
	sari:
	inc esi
	inc k
	cmp k,192
	jne reia2
    

    afisare_matrice_consola matricea,192
	
	initializare sirnr,192,0             ;reinitializez sirnr ul cu 0 ca sa l numai iau alta matrice
	
	
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	

	
	;terminarea programului
	push 0
	call exit
end start
