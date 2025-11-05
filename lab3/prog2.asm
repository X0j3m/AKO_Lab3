.686
.model flat
extern __write : PROC
extern __read : PROC
extern _ExitProcess@4 : PROC
public _main

.data
bufor_in db 16 dup (?)
rozmiar_bufor_in = $ - bufor_in
bufor_out_start db '+0.'
bufor_out db 8 dup ('0')
rozmiar_bufor_out = $ - bufor_out

.code
wyswietl PROC
	; wyswietla zawartosc bufora_out

	push rozmiar_bufor_out+3
	push OFFSET bufor_out_start
	push 1
	call __write
	add esp, 12
	ret
wyswietl ENDP

wczytaj PROC
	; wczytuje liczbe szesnastkowa 64 bitowa do bufora

	push rozmiar_bufor_in
	push OFFSET bufor_in
	push 0
	call __read
	add esp, 12
	ret
wczytaj ENDP

liczba_na_ascii PROC
	; zamienia wartosc liczby w AL na odpowiadajacy jej znak ASCII
	; wynik zapisany w AL

	add al, '0'
	ret
liczba_na_ascii ENDP

ascii_na_liczbe PROC
	; zamienia znak ASCII znajdujacy sie w AL na odpowiadajaca mu wartosc liczby
	; wynik zapisany w AL

	cmp al, '9'
	ja nie_cyfra
	sub al, '0'	
	ret

nie_cyfra:
	cmp al, 'a'
	jb duza_litera
	sub al, 'a'
	jmp koniec

duza_litera:
	sub al, 'A'

koniec:
	add al, 10
	ret
ascii_na_liczbe ENDP

konwersja_na_liczbe_32bity PROC
	; konwertuje liczbe szesnastkowa 32 bitowa 
	; zapisana w buforze (ktorego adres wskazuje ESI) na postac binarna
	; wynik zapisany w EAX

	push esi
	push ebx
	push ecx
	push edx

	mov ebx, 16					; mnoznik szesnastkowy
	mov eax, 0					; poczatkowa wartosc wyniku
	mov ecx, rozmiar_bufor_in/2	; liczba znakow ASCII do konwersji

petla_konwersji:
	mul ebx						; mnozenie przez 16
	mov edx, eax				; zapisanie obecnego wyniku do EDX
	mov eax, 0
	mov al, [esi]				; zapisanie znaku ASCII do AL
	call ascii_na_liczbe		; konwersja na wartosc liczby
	add eax, edx				; dodanie wartosci liczby do wyniku
	inc esi						; przejscie do nastepnego znaku ASCII w buforze
	loop petla_konwersji

	pop edx
	pop ecx
	pop ebx
	pop esi
	ret
konwersja_na_liczbe_32bity ENDP

konwertuj_ascii_hex_na_bin PROC
	; konwertuje liczbe szesnastkowa zapisana w buforze na na postac binarna
	; wynik zapisany w parze rejestrow EDX:EAX

	push esi
	
	mov esi, offset bufor_in
	call konwersja_na_liczbe_32bity	; konwersja starszych 32 bitow
	mov edx, eax					; przeniesienie starszej czesci wyniku do EDX
	add esi, 8
	call konwersja_na_liczbe_32bity	; konwersja mlodszych 32 bitow
	
	pop esi
	ret
konwertuj_ascii_hex_na_bin ENDP

przemnoz_przez_10_8 PROC
	; mnozy liczbe 64 bitowa zapisana w EDX:EAX przez 10^8
	; wynik zapisany w EDX:EAX:ECX

	push esi
	push ebx

	mov ebx, 100000000	; mnoznik 10^8

	push edx			; zachowanie starszej czesci liczby

	mul ebx				; mnozenie mlodszej czesci liczby przez 10^8
	
	mov esi, edx		; zachowanie przeniesienia
	mov ecx, eax		; zachowanie mlodszej czesci wyniku

	pop eax				; odtworzenie starszej czesci liczby
	mul ebx				; mnozenie starszej czesci liczby przez 10^8

	add eax, esi		; dodanie przeniesienia do srodkowej czesci wyniku
	adc edx, 0			; dodanie przeniesienia do starszej czesci wyniku

	pop ebx
	pop esi
	ret
przemnoz_przez_10_8 ENDP

podziel_przez_2_64 PROC
	; dzieli liczbe 96 bitowa zapisana w EDX:EAX:ECX przez 2^64
	; wynik zapisany w EAX

	mov eax, edx
	ret
podziel_przez_2_64 ENDP

konwertuj_bin_na_ascii_dec PROC
	; konwertuje liczbe 32 bitowa zapisana w EAX na postac dziesietna ASCII
	; wynik zapisany w buforze_out

	push eax
	push ebx
	push edx
	push esi

	mov esi, offset bufor_out
	add esi, rozmiar_bufor_out - 1	; ustawienie wskaznika na koniec bufora

	mov ebx, 10						; dzielnik dziesietny

petla_dzielenia:
	mov edx, 0
	div ebx					; dzielenie EAX przez 10
	push eax				; zachowanie wyniku dzielenia
	mov eax, edx			; reszta z dzielenia
	call liczba_na_ascii
	mov [esi], al			; zapisanie znaku ASCII do bufora
	pop eax					; przywrocenie wyniku dzielenia
	dec esi					; przesuniecie wskaznika bufora w lewo
	cmp eax, 0				; sprawdzenie czy wynik dzielenia to 0
	jne petla_dzielenia

	pop esi
	pop edx
	pop ebx
	pop eax
	ret
konwertuj_bin_na_ascii_dec ENDP

sprawdz_czy_ujemna PROC
	; sprawdza czy liczba 64 bitowa zapisana w EDX:EAX jest ujemna
	; jesli tak, konwertuje liczbe na dodatnia i zapisuje znak '-' na poczatku bufora wyjsciowego
	; wowczas program dziala dalej tak jakby liczba wejsciowa byla dodatnia
	; jesli nie liczba zostaje przesunieta o 1 bit w lewo celem zachowania zgodnosci z pierwotnym zalozeniem formatu liczby

	push ecx
	mov ecx, edx
	shr ecx, 31		; pobranie bitu znaku do CL

	cmp cl, 1		; CL = 1 jesli liczba jest ujemna, 0 w przeciwnym razie
	je ujemna
	shl eax, 1		; jesli liczba dodatnia, przesuniecie o 1 bit w lewo czesci mlodszej
	rcl edx, 1		; przesuniecie o 1 bit w lewo czesci starszej wraz z flaga CF
	pop ecx
	ret

ujemna:
	mov [bufor_out_start], byte ptr '-'		; zapisanie znaku '-' na poczatku bufora wyjsciowego
	; konwersja liczby ujemnej na dodatnia (U2 -> NKB)
	not eax									; zanegowanie bitow czesci mlodszej
	not edx									; zanegowanie bitow czesci starszej

	add eax, 1								; dodanie 1 do czesci mlodszej
	adc edx, 0								; dodanie ewentualnego przeniesienia do czesci starszej
	pop ecx
	ret
sprawdz_czy_ujemna ENDP

_main PROC
	pusha

	call wczytaj
	call konwertuj_ascii_hex_na_bin		; konwersja ciagu znakow ASCII na liczbe binarna 64 bitowa
	call sprawdz_czy_ujemna
	call przemnoz_przez_10_8			; mnozenie przez 10^8, rownoznaczne z przesunieciem przecinka o 8 miejsc w prawo
	call podziel_przez_2_64				; dzielenie przez 2^64, aby uzyskac wartosc dziesietna
	
	
	call konwertuj_bin_na_ascii_dec		; konwersja liczby binarnej na ciag znaow ASCII dziesietne
	call wyswietl

	popa
	push 0
	call _ExitProcess@4
_main ENDP

END