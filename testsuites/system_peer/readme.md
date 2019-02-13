# Modulo QSPN - Tests

## system_peer

Un programma per realizzare una testsuite con una script.

Una testsuite simulerà un numero di sistemi attraverso l'avvio in background di un numero
di processi `system_peer`. Ogni processo `system_peer` simula un *sistema* e quindi può gestire
una o più identità, o *nodi*.

Ogni sistema simulato ha un numero di interfacce di rete simulate.

Inoltre la script avvierà anche un numero di processi `eth_domain` o `radio_domain`. Infatti
il modulo Qspn ha bisogno di effettuare sia comunicazioni unicast in stream sia comunicazioni
broadcast in datagram.

### Compiti del sistema di RPC

Ogni processo `system_peer` dovrà stare in ascolto su un numero di interfacce
di rete per messaggi datagram e su un eguale numero di indirizzi IP linklocal
per connessioni.

Le interfacce di rete sono passate all'avvio
al `system_peer` con `-i`. Viene passato solo il nome. Il MAC e il linklocal
sono ottenuti con `fake_random_linklocal(fake_random_mac(pid, dev))`
cioè basandosi sul pid e sul nome dell'interfaccia.  
In questo modo anche le interfacce di un peer si potranno indicare dalla
linea di comando semplicemente con `peer_pid+peer_dev`. E il `system_peer` sarà
in grado di calcolare `peer_mac` e `peer_linklocal`.

### Simulazione dei compiti degli altri moduli

Il modulo Neighborhood realizza gli archi di nodo e ne misura i costi. Questo compito
va simulato nel programma `system_peer`.  
Gli archi di nodo sono passati all'avvio
al `system_peer` con `-a`. Viene passato `my_dev,peer_pid,peer_dev,cost`.

Una volta realizzato un "PseudoArc" il `system_peer` gli da un indice 0-based.
In questo modo quando si vorranno realizzare archi-identità sarà sufficiente
nella riga di comando indicare l'indice dello PseudoArc.

Il modulo Identities assegna ad ogni identità un NodeID e lo comunica al sistema
stesso e ai suoi diretti vicini. Questo compito
va simulato nel programma `system_peer`.  
La prima identità del sistema è la #0 e le successive (create con `enter_net` o con
`migrate`) sono associate al successivo indice 0-based. Il NodeID di una identità
nel sistema è calcolato con `fake_random_nodeid(pid, node_index)`.

In questo modo anche i NodeID delle identità di un sistema diretto vicino potranno essere
calcolate dal `system_peer`, purché conosca il `peer_pid+peer_node_index`.

Il modulo Identities crea anche gli archi-identità sopra gli archi di nodo. Questo compito
va simulato nel programma `system_peer`.  
Siccome le identità successive alla prima non sono create all'avvio del programma ma
in seguito (con una modalità `task`, come vedremo dopo) anche gli archi-identità vanno
creati in seguito.  
Il comando di creazione di una nuova identità viene impartito al `system_peer` come task
all'avvio nella forma `-t add_identity` come verrà dettagliato in seguito. In questo
comando si specificano anche gli archi-identità che la nuova identità avrà da subito.  
Il comando di creazione di un nuovo arco-identità su una vecchia identità viene impartito
al `system_peer` come task all'avvio nella forma `-t add_identityarc` come verrà
dettagliato in seguito.

La creazione di nuove identità (e la conseguente creazione di nuovi archi-identità)
è demandata al modulo Identities durante le operazioni `enter_net` e `migrate`. Queste
a loro volta sono orchestrate dal modulo Hooking che raccoglie le informazioni necessarie
alla costruzione dell'istanza di QspnManager (indirizzo, anzianità, ...). Inoltre
contemporaneamente il modulo Hooking provvede anche a segnalare i nuovi archi-qspn alle
istanze dei diretti vicini. Anche tutto questo va simulato nel programma `system_peer`.  
Il comando di creazione di una nuova istanza di QspnManager (nel caso `enter_net` o `migrate`)
viene impartito al `system_peer` come task all'avvio nella forma `-t enter_net` o `-t migrate`
come verrà dettagliato in seguito.  
Il comando di creazione di un nuovo arco-qspn su una vecchia istanza di QspnManager viene
impartito al `system_peer` come task all'avvio nella forma `-t add_qspnarc` come verrà
dettagliato in seguito.


### Caso d'uso: avvio di un sistema

Sul comando `system_peer` sono passati:

*   pid: Fake PID. un identificativo del sistema.
*   interfaces: Una serie di nomi di pseudo-nic.
*   arcs: Una serie di archi di nodo. In questo caso d'uso non servono.

E.g. `system_peer -p 1 -i eth0 -i eth1`. Avvia un sistema con due interfacce di rete e nessun arco.

Tutto ciò che dovrebbe essere random viene creato in modo pseudo-random inizializzando
il RNG sulla base del `pid`. Alcune cose (come spiegato sopra i NodeID, i MAC, i linklocal...)
siccome andrebbero comunicate agli altri sistemi attraverso altri moduli, oppure perché
ci conviene per poter predeterminare il risultato, sono calcolate con una funzione
(ad esempio `fake_random_nodeid`) sulla base di altri dati noti all'avvio della testsuite.

Sul comando `system_peer` posso passare la topologia. Altrimenti c'è una topologia di default.

Sul comando `system_peer` posso anche passare il primo indirizzo. Altrimenti viene scelto
in modo pseudo-random nell'ambito della topologia.

Il programma `system_peer` si mette in ascolto per messaggi datagram sulle interfacce
di rete specificate (almeno una) e per connessioni sugli indirizzi IP linklocal associati
ad esse (uno distinto per ogni interfaccia).

Al suo avvio il `system_peer` inizializza il modulo Qspn (con `init`)
e passa questi valori hard-coded:

*   `tasklet`
*   `max_paths`
*   `max_common_hops_ratio`
*   `arc_timeout`
*   `threshold_calculator`

Subito viene creato il primo nodo, cioè la prima identità nel sistema. Viene cioè individuato
il primo NodeID (`fake_random_nodeid`) e viene memorizzato insieme ad altre informazioni
su una istanza (della classe `IdentityData`) che è aggiunta ad una lista in memoria.

Il programma `system_peer` genera in modo pseudo-random, sulla base della topologia della rete,
un indirizzo Netsukuku per questo nodo (esso è infatti il primo nodo di una nuova rete).
Inoltre genera in modo pseudo-random l'identificativo di Fingerprint a livello 0 (esso
rimarrà lo stesso anche nelle successive identità) e le anzianità sono tutte a zero.

Riportiamo un elenco delle informazioni contenute in una istanza di IdentityData:

*   `nodeid`: NodeID di questa identità nel nostro sistema.
*   `my_naddr`: Indirizzo Netsukuku.
*   `my_fp`: Fingerprint.
*   `copy_of_identity`: Riferimento all'istanza da cui è stata generata. Per la prima è null.
*   `connectivity_from_level`: Vale 0 se è l'identità principale.
*   `connectivity_to_level`: Vale 0 se è l'identità principale.
*   `identity_arcs`: Lista 0-based di archi-identità (istanze di IdentityArc).
*   `qspn_mgr`: Istanza di QspnManager.

Riportiamo un elenco delle informazioni contenute in una istanza di Identityarc:

*   `arc`: Arco di nodo.
*   `peer_nodeid`: Identità nel peer.
*   `qspn_arc`: Istanza di IQspnArc.

Dopo aver creato la prima identità, il `system_peer` crea la relativa istanza di `qspn_mgr`
con il costruttore `create_net`, a cui passa:

*   `my_naddr`.
*   `my_fingerprint`.
*   `stub_factory`.

Ci si aspetta che il modulo Qspn emetta per questa istanza immediatamente il segnale
di `qspn_bootstrap_complete`.


### Caso d'uso: incontro dei primi due nodi

Quando viene operato un ingresso in altra rete, in termini generali, si ha che
un g-nodo *w* di livello *k* vuole entrare in *g* ∈ *G* di livello *hl*.

Partiamo però da un caso semplice, che è anche il primo caso che si manifesta nella
creazione di qualsiasi rete. Un sistema appena avviato incontra un altro sistema
in uno stato analogo.  
Nel sistema *a* appena avviato esiste una sola identità *a0* che è l'unico nodo di
una rete a sé. Analogamente in *b* l'identità *b0*. Nel momento in cui questi due
sistemi si incontrano (e quindi si incontrano le loro identità principali) viene deciso
che uno dei due cerca di entrare nella rete dell'altro. Diciamo che sia *a*.  
Il nodo *a0* (che costituisce *w* da solo, con *k* = 0) entra nel g-nodo *g* di
livello *hl* = 1 che contiene *b0*.

Assumiamo che il sistema *a* e il sistema *b* hanno entrambi una interfaccia (eth0) e un arco
è stato definito tra le due. Tale arco è indicato con #0 sia in *a* che in *b*.  
Cioè assumiamo che lo script abbia avviato i due processi `system_peer` che rappresentano
*a* e *b* indicando negli argomenti del comando l'interfaccia e l'arco.

I.e.

```
system_peer -p 1 -i eth0 -a eth0,2,eth0,2000
system_peer -p 2 -i eth0 -a eth0,1,eth0,2000
# l'ultimo parametro è il costo dell'arco in usec.
```

Lo script sa che in seguito (ad esempio dopo 1000 msec dall'avvio del `system_peer`) occorre
creare in *a* una nuova identità *a1* a partire da *a0*, la quale non aveva archi-identità.  
Poi occorrerà aggiungere in *a* un arco-identità basato sull'arco #0 che unisce *a1* a *b0*.  
Allo stesso tempo occorrerà aggiungere un arco-identità su *b* basato sull'arco #0 che unisce *b0* a *a1*.

Dopo che questa nuova identità (*a1* in *a*) e questi nuovi archi-identità (*a1-b0* in *a* e *b0-a1* in *b*)
sono stati creati si potrà proseguire.  
Notare che queste operazioni (creazione di identità e archi-identità) non hanno comportato
alcuna operazione sul modulo Qspn. In particolare non c'è stata alcuna comunicazione avviata
dal modulo Qspn sui socket locali costruiti dal sistema RPC.

Quindi, solo in seguito (ad esempio dopo 1500 msec dall'avvio del `system_peer`) lo script
avvierà le operazioni, che adesso vedremo, che influiscono sulle istanze di QspnManager.

Lo script sa quale indirizzo ha *g* (il g-nodo di livello 1 che contiene *b0*)
e quale posizione in *g* viene assegnata al futuro *a1*.  
Analogamente sa quale anzianità ha *g* e i suoi superiori e quale anzianità
in *g* viene assegnata al futuro *a1*.  
Comunica questi dati al `system_peer` di *a* dicendo di operare su *a0* con `guest_level=0`.

Il `system_peer` di *a* completa con gli altri dati che già conosce di *a0*:

*   le posizioni dell'indirizzo Netsukuku dal livello 0 fino al livello *hl* - 1 escluso. In questo caso nessuna.
*   l'identificativo del fingerprint a livello 0.
*   le anzianità dal livello 0 fino al livello *k* escluso. In questo caso nessuna.

Il `system_peer` di *a* costruisce l'indirizzo Netsukuku e il fingerprint a livello 0 per *a1*.
Per l'identificativo del fingerprint a livello 0, usa lo stesso che aveva *a0*. Per le posizioni dell'indirizzo Netsukuku:

*   ai livelli maggiori o uguali a *hl* - 1 usa le posizioni di *g* e la posizione assegnata in *g*.
*   ai livelli minori di *hl* - 1 usa le posizioni che aveva *a0*.

Per le anzianità del fingerprint:

*   ai livelli maggiori o uguali a *hl* - 1 usa le anzianità di *g* e l'anzianità assegnata in *g*.
*   ai livelli maggiori o uguali a *k* e minori di *hl* - 1 usa zero (nel senso che è il primo g-nodo).
*   ai livelli minori di *k* usa le anzianità che erano dei g-nodi a cui apparteneva *a0*.

Poi il `system_peer` di *a* costruisce le istanze degli archi. In questo caso banale abbiamo
un solo arco-identità sull'arco #0 che collega *a1* a *b0* (vedremo in seguito che possono esserci diversi
casi da gestire in modo diverso). Non esisteva per esso un IQspnArc di *a0*. Il `system_peer` di *a*
costruisce per esso un IQspnArc da passare all'istanza di QspnManager di *a1*.

Infine il `system_peer` di *a* prepara una istanza di IQspnStubFactory.

Finiti i preparativi, ora il `system_peer` di *a* costruisce una istanza di QspnManager per *a1*
con il costruttore `enter_net` e passa:

*   `internal_arc_set`: lista vuota
*   `internal_arc_prev_arc_set`: lista vuota
*   `internal_arc_peer_naddr_set`: lista vuota
*   `external_arc_set`: lista con l'arco IQspnArc sull'arco #0 che congiunge la nuova identità *a1* con *b0*.
*   `my_naddr`: vedi sopra.
*   `my_fingerprint`: vedi sopra.
*   `update_internal_fingerprints`: funzione callback (non sarà chiamata in questo caso)
*   `stub_factory`
*   `guest_gnode_level`: 0
*   `host_gnode_level`: 1
*   `previous_identity`: *a0*

Contemporaneamente, il `system_peer` di *b* costruisce, per l'arco-identità (creato di recente) sull'arco #0
che collega *b0* a *a1*, un IQspnArc e lo passa all'istanza di QspnManager di *b0* con il
metodo `add_arc`.

Quindi, ricapitolando le informazioni che lo script deve passare ai vari processi `system_peer`
che lancia, i task per *a* sono:

```
 -t add_identity,1000,0,0+0
 -t enter_net,1500,0,1,0,1:1:0:3,1:0:0:0,0+0
```

cioè:

*   passo 1: crea una nuova identità con il suo arco-identità.
    *   `ms_wait`: aspetta 1000 msec.
    *   `my_old_id`: 0 è l'indice della mia identità vecchia, sulla quale verrà creata la
        nuova identità con indice 1.
    *   `arc_list`: lista di archi-identità da aggiungere alla nuova identità. Separati da `_`.
        Ogni arco-identità è fatto di `arc_num+peer_id`.
*   passo 2: crea una istanza di QspnManager per la nuova identità che fa ingresso.
    *   `ms_wait`: aspetta 1500 msec.
    *   `my_old_id` e `my_new_id`: 0 è l'indice della mia identità vecchia, 1 è l'indice della
        mia identità nuova.
    *   `guest_level`: 0 è il livello del g-nodo *w* che entra in *g*.
    *   `in_g_naddr`: indirizzo di *g* e nuova posizione assegnata.  
        1:1:0:3 significa che *g* ha posizione 1:0:3 (è implicitamente indicato `host_level` = 4-3 = 1)
        e in *g* la nuova posizione assegnata è 1.
    *   `in_g_elderships`: anzianità di *g* e nuova anzianità assegnata.
    *   `external_arc_list`: lista di archi-identità della nuova identità che sono archi esterni a *w*.
        Separati da `_`. Ogni arco-identità è indicato con `arc_num+peer_id`.

I task per *b* sono:

```
 -t add_identityarc,1000,0,0+1
 -t add_qspnarc,1500,0,0+1
```

cioè:

*   passo 1: crea un nuovo arco-identità.
    *   `ms_wait`: aspetta 1000 msec.
    *   `my_id`: 0 è l'indice della mia identità.
    *   `arc_num+peer_id`: 0 è l'indice dell'arco. 1 è l'indice dell'identità nel sistema peer.
*   passo 2: crea un nuovo arco-qspn.
    *   `ms_wait`: aspetta 1500 msec.
    *   `my_id`: 0 è l'indice della mia identità.
    *   `arc_num+peer_id`: 0 è l'indice dell'arco. 1 è l'indice dell'identità nel sistema peer.

#### Dismissione della precedente identità

Dopo aver creato l'identità *a1* e la sua istanza di QspnManager, si potrebbe in questo caso
dismettere immediatamente la vecchia istanza di QspnManager dell'identità *a0*. Però in
generale, quando a fare ingresso è un g-nodo, potrebbe darsi che
gli altri nodi del g-nodo *w* non hanno ancora finito di costruire la nuova
istanza e il costruttore `enter_net` ha bisogno della `previous_identity` per dare
uno sguardo ai suoi archi-identità (che sono gli archi-identità vecchi).  
Quindi occorre, prima aspettare un po' per essere sicuri che i nodi diretti
vicini siano pronti, e poi rimuovere la vecchia istanza di QspnManager
che era di *a0*.

Per questo il `system_peer` nel task `enter_net`, dopo aver creato l'istanza
di QspnManager per la nuova identità che fa ingresso, attende 500 msec e poi
rimuove il QspnManager della vecchia identità.

Prima di dismettere il QspnManager di *a0*, il system_peer di *a* chiama sull'istanza di QspnManager
di *a0* il metodo `destroy` per segnalare ai suoi diretti vicini esterni a *w*
che sta uscendo dalla rete.

### Caso d'uso: TODO...

...

### Lista tasks

Segue un elenco dei comandi di tipo task che si possono dare al programma al suo
avvio perché siano eseguiti dopo un dato tempo.

*   `add_identity`: Aggiunge una identità, come è stato illustrato in precedenza. I parametri sono:
    *   `ms_wait`.
    *   `my_old_id`.
    *   `identity_arc_list`.
*   `add_identityarc`: Aggiunge un arco-identità, come è stato illustrato in precedenza.
    I parametri sono:
    *   `ms_wait`.
    *   `my_id`.
    *   `identity_arc`.
*   `enter_net`: Crea una nuova istanza di QspnManager per fare ingresso in una nuova rete, come
    è stato illustrato in precedenza. I parametri sono:
    *   `ms_wait`.
    *   `my_old_id`.
    *   `my_new_id`.
    *   `guest_level`.
    *   `in_g_naddr`.
    *   `in_g_elderships`.
    *   `external_identity_arc_list`.
*   `migrate`: Crea una nuova istanza di QspnManager per fare una migrazione nella rete, come
    è stato illustrato in precedenza. I parametri sono:
    *   `ms_wait`.
    *   ... TODO.
*   `add_qspnarc`: Aggiunge un arco-qspn ad una istanza di QspnManager, come è stato illustrato in precedenza.
    I parametri sono:
    *   `ms_wait`.
    *   `my_id`.
    *   `identity_arc`.
*   `remove_qspnarc`: Rimuove (forzatamente) un arco-qspn da una istanza di QspnManager.
    I parametri sono:
    *   `ms_wait`.
    *   `my_id`.
    *   `arc_num`.
    *   `peer_id`.
*   `changecost_arc`: Cambia il costo di un arco, aggiornando gli archi-qspn esistenti.
    I parametri sono:
    *   `ms_wait`.
    *   `arc_num`.
    *   `usec_rtt`.
*   `addtag`: Aggiunge una label alla lista degli eventi. I parametri sono:
    *   `ms_wait`.
    *   `label`.
*   `check_destnum`: Verifica il numero di destinazioni note ad una data istanza di QspnManager.
    *   `ms_wait`.
    *   `my_id`.
    *   `expected`.
    *   `label`.

***

#### Annotazioni

Il programma `system_peer` deve gestire il segnale `gnode_splitted`. Andrebbe
chiamato `signal_split` del modulo Hooking, che chiamerebbe `you_have_splitted`
del modulo Hooking nel nodo diretto vicino, che chiamarebbe con propagazione
a tutto il g-nodo il metodo `we_have_splitted` del modulo Hooking, che
chiamarebbe infine `exit_network` del modulo Qspn.  
In conclusione, va chiamato `exit_network` del modulo Qspn su tutti i
nodi dell'isola scollegata del g-nodo splittato.


Il programma `system_peer` deve gestire il segnale `presence_notified`.
Questo segnale viene emesso da un nodo che ha da (poco) tempo completato
il suo bootstrap; tale nodo inoltre era stato creato (vedremo sotto) sulla
base di uno precedente in occasione di una migrazione. In risposta a questo
evento il programma deve identificare l'identità precedente e su questa
iniziare le operazioni di rimozione degli archi che vanno verso l'esterno
del g-nodo di cui essa è a supporto della connettività interna.  
Per ogni nodo (identità) gestita da un processo `system_peer` il processo ha
memoria del fatto che si tratta di un nodo di connettività e a quali livelli.


Il programma `system_peer` deve individuare per una chiamata remota ricevuta
e passata a un suo skeleton, quindi sulla base di un CallerInfo, da quale
suo arco (istanza di IQspnArc) è provenuta. Questo lo fa sul metodo
        `public abstract bool i_qspn_comes_from(CallerInfo rpc_caller);`
dell'interfaccia IQspnArc.
