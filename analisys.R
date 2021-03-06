setwd("/Volumes/Archive/uni/DataScience/policesViolence") 
library(dplyr)
library(ggplot2)
library(waffle)
library(plotly)
library(usmap)
library(calendR)
library(treemap)
library(networkD3)

policesViolence <- read.csv("fatalEncountersDotOrg.csv")
policesViolence <- as_tibble(policesViolence)
#phase: DATA CLEANING
#alcune osservazioni del dataset sono un po' errate probabilmente per errori di battitura o sviste, quindi si è deciso di normalizzarle con valori nulli o arrotondarli a valori simili

policesViolence$Age[which(policesViolence$Age == "")]="NA"
policesViolence$Age[which(policesViolence$Age < 1)]="NA" #eg. (0.25 non è un'età)
policesViolence$Age=as.numeric(policesViolence$Age) #per togliere i range d'età (eg. 18-25 lo assumo come NA)

policesViolence$Gender[which(policesViolence$Gender=="")]="NA"

policesViolence$Race[which(policesViolence$Race=="")]="Race unspecified"
policesViolence$Race[which(policesViolence$Race=="Christopher Anthony Alexander")]="Race unspecified"
policesViolence$Race[which(policesViolence$Race=="European-American/European-American/White")]="European-American/White"
policesViolence$Race[which(policesViolence$Race=="european-American/White")]="European-American/White"
policesViolence$Race[which(policesViolence$Race=="African-American/Black African-American/Black Not imputed")]="African-American/Black"

policesViolence$Location.of.death..city.[which(policesViolence$Location.of.death..city.=="")]="NA"

policesViolence$Foreknowledge.of.mental.illness..INTERNAL.USE..NOT.FOR.ANALYSIS[which(policesViolence$Foreknowledge.of.mental.illness..INTERNAL.USE..NOT.FOR.ANALYSIS=="")]="NA"

policesViolence$date<-format(as.Date(policesViolence$Date.of.injury.resulting.in.death..month.day.year., '%m/%d/%Y'), "%Y/%m/%d") #creo la proprietà data che verrà utilizzata numerose volte
policesViolence <- policesViolence %>%
  filter(format(as.Date(date, "%Y/%m/%d"),"%Y")<2022) #vi è un'osservazione placeholder con data 2200, rimuoviamola

############################################

sumGender <- policesViolence %>%
  group_by(Gender) %>%
  summarise ( totali = n()) %>%
  arrange(-totali)

#creo una semplice percentuale
sumGender<-sumGender %>%
  mutate(percentuale=round(totali/sum(sumGender$totali)*100, digits=2))
  
ggplot(sumGender, aes(x="", y=totali, fill=paste(Gender, "-",percentuale,"%"))) +
  geom_bar(stat="identity", width = 1)+
  coord_polar("y", start=0)+
  labs(x=NULL, y=NULL, fill="Gender")+
  theme_classic()+
  theme(axis.line = element_blank(),
        axis.text = element_blank(),
        legend.text = element_text(size=11),
        axis.ticks = element_blank())+
  guides(fill = guide_legend(title = "Genere"))+
  scale_fill_manual(values=c("#cf91ea","#226696","red","green"))+
  ggtitle("Per genere","Totale delle vittime suddivise per sesso")


############################################

ageAndGender <- policesViolence %>%
  group_by(Age, Gender) %>%
  summarise (n = n()) %>%
  arrange (n) 

ggplot(ageAndGender, aes(x = Age, y = n, fill = Gender)) + 
  geom_bar(stat = "identity")+
  scale_fill_manual(values = c("#cf91ea", "#226696", "red", "green"))+
  theme_minimal()+
  theme(
    legend.text = element_text(size=11)
  )+
  ylab("Numero di vittime")+
  xlab("Età")+
  ggtitle("Età & Genere","Vittime raggruppate per età e sesso")

############################################

genderRace <- policesViolence %>%
  group_by(Gender, Race) %>%
  summarise(n=n()) %>%
  arrange(-n)

# treemap per razza e sottocategoria il genere
treemap(genderRace,
        index=c("Race","Gender"),
        vSize="n",
        type="index",
        fontsize.labels=c(17,13),
        fontcolor.labels=c("white","black"),
        fontface.labels=c(2,3),
        bg.labels=c("transparent"), 
        align.labels=list(
          c("center", "center"), 
          c("right", "bottom")
        ),
        border.col=c("black","white"),
        border.lwds=c(0,1),
        title = "Per sesso ed etnia",
        palette="Set2"
)

############################################

byRace <- policesViolence%>%
  group_by(Race) %>%
  summarise(n=n()) %>%
  arrange(-n)

colnames(byRace) <- c("Race","n") #fondamentale
names(byRace$n) = paste0(byRace$Race, "-", byRace$n, " [",round(byRace$n/sum(byRace$n)*100),"%]") #aggiungo la quantità e la percentuale di ogni razza al nome

waffle(round(byRace$n/sum(byRace$n)*100), rows=10, colors = c("#0b827c", "#707070", "black", "#BD0026","#d8ce15","#15b8d8","pink"), legend_pos = "right", title = "Etnie distribuite su 100 elementi")
#POPOLAZIONE AFROAMERICANA: ~40mln, carnagione bianca ~200mln
############################################

yearAndRace <- policesViolence %>%
  mutate(anno=format(as.Date(date, "%Y/%m/%d"), "%Y")) %>%
  group_by(Race, anno) %>%
  summarise(n=n())

ggplot(yearAndRace, aes(x = anno, y = n, group=Race, colour=Race))+
  geom_line(size=1.2)+
  scale_color_manual(values=c("black", "#d8ce15", "#0b827c", "#BD0026","pink","#15b8d8","#707070"))+
  labs(x = "Anno",
       y = "Numero di vittime",
       colour = "Race")+
  theme_minimal()+
  theme(
    axis.text.x = element_text(angle=70)
  )+
  ggtitle("Anni & Etnie", "Le vittime divise per etnia negli anni")

############################################
#mi servirà creare una variabile anno per poter raggruppare per esso
groupedYears <- policesViolence %>%
  mutate(anno=format(as.Date(date, "%Y/%m/%d"),"%Y")) %>% 
  group_by(anno) %>%
  summarise (n=n())

#per annotate(geom="text") ho dovuto shiftare al 2019 anche se gli eventi sono accaduti nel 2020 altrimenti l'ettichetta esce dal grafico
ggplot(groupedYears, aes(x = anno, y = n, group=1)) +
  geom_line(size=1.2, color="#352c2e") +
  geom_point() +
  annotate(geom="text", x="2019", y=1600, label="Breonna Taylor", color="#BD0026",size=4.5)+ 
  annotate(geom="point", x="2020", y=1570, color="#BD0026")+
  annotate(geom="text", x="2019", y=1500, label="George Floyd", color="#BD0026", size=4.5)+
  annotate(geom="point", x="2020", y=1470, color="#BD0026") +
  ylab("Numero di vittime")+
  xlab("Anno")+
  ggtitle("Negli anni", "Dal 2000 al 2021")+
  theme_minimal()+
  theme(
    axis.text.x = element_text(angle=70),
    axis.text.y = element_text(angle=320)
  )+
  geom_vline(aes(xintercept="2020"), color="#2681e2", size=0.5)+
  geom_smooth(color="#BD0026")


############################################
#le osservazioni arrivano fino a dicembre 2021, mi fermo ad ottobre, mi interessa vedere un range temporale ridotto -> 1 anno prima e 1 anno e mezzo dopo dell'inizio delle proteste
blmYears <- policesViolence%>%
  mutate(AnnoMese = format(as.Date(date, "%Y/%m/%d"),"%Y/%m"))%>%
  filter(AnnoMese > "2019/02", AnnoMese < "2021/10")%>% 
  group_by(AnnoMese) %>%
  summarise(n=n())

ggplot(blmYears, aes(x=AnnoMese, y=n)) +
  geom_segment( aes(x=AnnoMese, xend=AnnoMese, y=0, yend=n), color="grey") +
  geom_point( color="#BD0026", size=4) +
  theme_light() +
  theme(
    panel.grid.major.x = element_blank(),
    panel.border = element_blank(),
    axis.text.x = element_text(angle=90)
  ) +
  annotate(geom="text", x="2020/05", y=230, label="'Inizio' delle proteste")+
  annotate(geom="point", x="2020/05", y=215, size=10, shape=21, fill="transparent")+
  geom_hline(aes(yintercept=mean(n)), color="#2681e2", size=0.7)+
  xlab("Mese/Anno") +
  ylab("Numero di vittime")+
  ggtitle("Prima e dopo le proteste BLM", "Movimento BLM fondato nel 2013")

############################################
#Interessante non solo per i giorni (festività, eventi) ma anche per i mesi (stagioni -> in inverno si sta più in casa rispetto alla primavera, cambia qualcosa?)
#Ricordiamoci che il 2020 è stato l'anno con il maggior numero di vittime
dayInTheYear <- policesViolence %>%
  filter(format(as.Date(date, "%Y/%m/%d"),"%Y")==2020) %>%
  mutate(day = format(as.Date(date, "%Y/%m/%d"), "%j")) %>%
  group_by(day) %>%
  summarise(n=n()) %>%
  arrange(-n)
dayInTheYear <- dayInTheYear %>%
  filter(n>5)
calendR(
        orientation = "portrait", 
        months.pos = 0,
        year = 2020,
        start = "M",
        special.days = as.numeric(dayInTheYear$day), #tagliamo a top 50 
        special.col =  "#BD0026",
        low.col = "#a1a2af",
        title= "I giorni con più di 5 vittime nel 2020"
        )

############################################
groupedByState <- policesViolence %>%
  group_by(State) %>%
  summarise(n=n()) %>%
  arrange(-n)

colnames(groupedByState) <- c("state","n") 

plot_usmap(data = groupedByState, values = "n", color = "red") + 
  scale_fill_continuous(low = "white", high = "red", name = "Numero di vittime", label = scales::comma) + 
  labs(title = "Heatmap degli stati", subtitle = "Quantità di vittime raggruppata per stato") +
  theme(legend.position = "right")


############################################


#semplicemente sfrutto le coordinate Latitudine e Longitudine poiché mi sono state fornite
usaMapInter <- policesViolence %>%
  plot_ly(
    lat= ~policesViolence$Latitude,
    lon= ~policesViolence$Longitude,
    marker= list(color="#BD0026"),
    type = 'scattermapbox')
usaMapInter <- usaMapInter %>%
  layout(
    mapbox=list(
      style='open-street-map',
      zoom=2.5,
      center=list(lon=-88, lat=34)
    )
  )
usaMapInter
############################################

#raggruppiamo per etnia, causa del decesso, mental illness (se la vittima era in una condizione mentale particolare).
#Mental illness interpretato come minaccia per l'agente di polizia, poiché una persona sotto sostanze stupefacenti solitamente ha un probabilità più alta di essere pericoloso rispetto a una persona mentalmente sobria.
RaceWeaponIllness <- policesViolence %>%
  group_by(Race, Highest.level.of.force, Foreknowledge.of.mental.illness..INTERNAL.USE..NOT.FOR.ANALYSIS) %>%
  summarise (n=n()) %>%
  arrange(-n)

#siccome voglio creare il Sankey a 3 livelli, devo mettere la destinazione (target) del livello intermedio anche come partenza (source) per il livello finale
links<- data.frame(
  source= c(RaceWeaponIllness$Race, RaceWeaponIllness$Highest.level.of.force),
  target= c(RaceWeaponIllness$Highest.level.of.force, RaceWeaponIllness$Foreknowledge.of.mental.illness..INTERNAL.USE..NOT.FOR.ANALYSIS),
  value= RaceWeaponIllness$n
)
nodes <- data.frame(
  name=c(as.character(links$source), 
         as.character(links$target)) %>% unique()
)

links$IDsource <- match(links$source, nodes$name)-1 
links$IDtarget <- match(links$target, nodes$name)-1
sankeyRWI <- sankeyNetwork(Links = links, Nodes = nodes,
                   Source = "IDsource", Target = "IDtarget",
                   Value = "value", NodeID = "name", 
                   sinksRight=TRUE, fontSize = 9, nodeWidth = 8,
                   ) #attenzione a fontSize, è un widgetHTML quindi il browser può modificare la dimensione in base alle impostazioni personalizzate

sankeyRWI