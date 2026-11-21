# BisqFTS

Obraz Dockera z aplikacją [Bisq](https://bisq.network) (zdecentralizowana giełda bitcoina),
obsługiwaną z przeglądarki albo z klienta VNC. Podstawa: `jlesage/baseimage-gui` (Debian 13).

## Budowa

```
docker build -t bisqfts:1.10.12 .
```

Inna wersja Bisqa:

```
docker build --build-arg BISQ_VERSION=1.10.13 -t bisqfts:1.10.13 .
```

Budowa pobiera pakiet `.deb` z wydania Bisqa na GitHubie i sprawdza jego podpis. Przyjmuje tylko
podpis kluczem, którego pełny odcisk jest na liście `BISQ_SIGNER_FPRS` w `Dockerfile`. Podpis
innym kluczem przerywa budowę: nowy klucz Bisqa dopisuje się do listy dopiero po sprawdzeniu.

## Uruchomienie

```
docker run -d --name bisqfts -p 5800:5800 -p 5900:5900 -e USER_ID=99 -e GROUP_ID=100 -e UMASK=0077 -e VNC_PASSWORD=haslo --memory=8g --stop-timeout=60 -v /sciezka/do/danych:/config bisqfts:1.10.12
```

GUI: `http://<host>:5800` w przeglądarce albo `<host>:5900` w kliencie VNC.

| Parametr | Znaczenie |
|---|---|
| `USER_ID`, `GROUP_ID` | właściciel plików w `/config`; na Unraidzie `99` (`nobody`) i `100` (`users`) |
| `UMASK` | `0077`: nowe pliki 600, katalogi 700, portfel czyta tylko właściciel |
| `VNC_PASSWORD` | hasło do GUI (przeglądarka i VNC); ustawiać zawsze, patrz „Tor” |
| `--memory` | limit pamięci; Bisq bierze na stertę Javy 50 % limitu, bez limitu połowę pamięci hosta |
| `--stop-timeout` | co najmniej 30 s: tyle Bisq dostaje na zamknięcie portfela i Tora |
| `JAVA_TOOL_OPTIONS` | dodatkowe opcje Javy, np. `-Xmx3g`; mają pierwszeństwo przed opcjami obrazu |

## Dane

| Katalog | Zawartość |
|---|---|
| `/config/bisq` | wszystko, co należy do Bisqa: portfel, stan DAO, `bisq.properties`, logi (`--appDataDir`) |
| `/config/xdg`, `/config/log`, `/config/var` | ustawienia GUI i usług obrazu; odtwarzają się same |

Kopia zapasowa portfela to kopia `/config/bisq` przy zatrzymanym kontenerze.

## Ekran

Interfejs WWW dopasowuje ekran kontenera do okna przeglądarki (w panelu po lewej
**Scaling mode → Remote Resizing**), a usługa `bisq-maximize` trzyma okno Bisqa zmaksymalizowane,
więc idzie ono za rozmiarem przeglądarki. Gdy okno przeglądarki jest mniejsze niż minimalne okno
Bisqa (1020×619), interfejs domyślnie skaluje obraz. Wybór w panelu zapamiętuje przeglądarka.

## Tor

Bisq uruchamia Tora w piaskownicy `sandy`. W kontenerze z domyślnymi ustawieniami Dockera
piaskownica działa na poziomie `host-network` (jądro 6.12 lub nowsze) albo `host-network-signals`
(starsze): Tor nie czyta plików portfela, ale może łączyć się z usługami w sieci kontenera, w tym
z VNC tego kontenera, i w sieci lokalnej. Dlatego `VNC_PASSWORD` jest potrzebne zawsze. Najwyższy
poziom, z własną siecią Tora, wymaga zgody kontenera na przestrzenie nazw użytkownika; ten obraz
go nie włącza.

## Unraid

1. Obraz na serwer: `docker save bisqfts:1.10.12 | ssh <serwer> docker load`.
2. Szablon `unraid/my-BisqFTS.xml` do `/boot/config/plugins/dockerMan/templates-user/`,
   potem **Docker → Add Container → BisqFTS → Apply**.
3. Nowa wersja: obraz z nowym tagiem na serwer, zmiana tagu w polu **Repository**, **Apply**.
   Przycisk aktualizacji Unraida zawsze próbuje pobrać obraz z rejestru, więc tu nie działa.
