-- Hinweis: Öffnen Sie diese Datei im Editor medit
-- Zunächst: Neue Datenbank anlegen, z.B. workshop
-- Laden der PostGIS-Funktionen
CREATE EXTENSION postgis;

/* AAAAAAAAAAAAAAAAAAA */
-- Anlegen der Tabelle für die Schutzgebiete:
CREATE TABLE schutzgebiet
(
gid serial NOT NULL,
-- serial erzeugt eine Sequenz und setzt sie als Defaultwert, der Datentyp ist INTEGER  
CONSTRAINT "schutzgebiet_pkey" PRIMARY KEY (gid)
-- definiert das Feld gid als Primärschlüsselfeld dieser Tabelle
);
SELECT addgeometrycolumn('schutzgebiet', 'the_geom', 4326, 'Polygon', 2);
-- Hinzufügen der Geometrie über PostGIS-Funktion
CREATE INDEX schutzgebiet_gidx ON schutzgebiet USING gist (the_geom);
-- Anlegen eines räumlichen Index

/* BBBBBBBBBBBBBBBBBBB */
-- Hinzufügen der Sachdatenfelder:
ALTER TABLE schutzgebiet ADD COLUMN gebietsname character varying(64);
ALTER TABLE schutzgebiet ALTER COLUMN gebietsname SET NOT NULL; 
-- jedes Gebiet MUSS einen Namen haben
ALTER TABLE schutzgebiet ALTER COLUMN gebietsname SET DEFAULT 'unbekannt'::varchar;
-- ist ein Feld NOT NULL, sollte ein Defaultwert vergeben werden
ALTER TABLE schutzgebiet ADD COLUMN nummer character varying(64);
-- ein Gebiet KANN eine Nummer haben
ALTER TABLE schutzgebiet ADD COLUMN unterschutzstellungsdatum date;
ALTER TABLE schutzgebiet ALTER COLUMN unterschutzstellungsdatum SET NOT NULL;
-- jedes Gebiet MUSS ein Unterschutzstellungsdatum haben
ALTER TABLE schutzgebiet ALTER COLUMN unterschutzstellungsdatum SET DEFAULT ('now'::text)::date;
-- ist ein Feld NOT NULL, sollte ein Defaultwert vergeben werden, hier das Tagesdatum
ALTER TABLE schutzgebiet ADD CONSTRAINT udatum_nach_1930 CHECK (unterschutzstellungsdatum >= '1930-01-01'::date);
-- stellt sicher, dass kein Datum vor dem 1.1.1930 eingegeben werden kann
ALTER TABLE schutzgebiet ADD COLUMN groesse integer;
ALTER TABLE schutzgebiet ALTER COLUMN groesse SET NOT NULL;
-- jedes Gebiet hat eine Gebietsgrösse
ALTER TABLE schutzgebiet ALTER COLUMN groesse SET DEFAULT 1;
ALTER TABLE schutzgebiet ADD CONSTRAINT hat_groesse CHECK (groesse > 0);
-- stellt sicher, dass die Gebeitsgrösse mindestens 1 ist
ALTER TABLE schutzgebiet ADD COLUMN gebietstyp character varying(64);

/* CCCCCCCCCCCCCCCCC*/
-- Kommentare sind oft hilfreich, v.a. wenn eher kryptische Feldnamen benutzt werden
-- Kommentare werden in der DataDrivenInputMask als Tooltip angezeigt
COMMENT ON COLUMN schutzgebiet.unterschutzstellungsdatum IS 'Das in der Schutzgebietsverordnung genannte Datum der Unterschutzstellung';

/* DDDDDDDDDDDDDDDDD */
-- Normalisierung des Gebietstyps:
ALTER TABLE schutzgebiet DROP COLUMN gebietstyp;
-- entfernen des nun überflüssigen Gebietstyps
CREATE TABLE gebietstyp
(
id integer NOT NULL,
gebietstyp character varying(64) NOT NULL,
-- in dieses Feld kommt der Gebietstyp rein
CONSTRAINT "gebietstyp_pkey" PRIMARY KEY (id)
);
INSERT INTO gebietstyp VALUES (1, 'NSG'); -- Naturschutzgebiet
INSERT INTO gebietstyp VALUES (2, 'LSG'); -- Landschaftsschutzgebiet
INSERT INTO gebietstyp VALUES (3, 'FFH'); -- Schutzgebiet nach der FFH-Richtlinie

ALTER TABLE schutzgebiet ADD COLUMN gebietstyp_id integer;
-- Anlage des neuen Feldes, das die Referenz auf gebietstyp.id aufnehmen soll
ALTER TABLE schutzgebiet
  ADD CONSTRAINT fk_schutzgebiet_gebietstyp FOREIGN KEY (gebietstyp_id)
      REFERENCES gebietstyp (id) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE RESTRICT;
-- Herstellen der referenziellen Integrität; nun kann
-- 1) keine gebietstyp_id eingetragen werden, die keine Entsprechung in gebietstyp hat und
-- 2) kein Gebietstyp gelöscht werden, zu dem es noch Schutzgebiete gibt (ON DELETE RESTRICT).
-- 3) Sollte die gebietstyp.id eines Gebietstyps geändert werden, wird die gebietstyp_id aller
--    entsprechenden Schutzgebiete geändert (ON UPDATE CASCADE), sollte man aber nicht tun, denn
--    eine ID sollte eigentlich über den gesamten Lebenslauf des Datensatzes konstant bleiben.
CREATE INDEX gebietstyp_idx ON schutzgebiet (gebietstyp_id);
-- anlegen eines Index auf den Fremdschlüssel; bei vielen Datensätzen wird
-- damit die Verknüpfung deutlich beschleunigt


/* EEEEEEEEEEEEEEEEEEEEEE */
-- mehrere Gebietstypen pro Schutzgebiet mit jeweiligem Unterschutzstellungsdatum:
ALTER TABLE schutzgebiet DROP COLUMN gebietstyp_id;
-- entfernen des nun überflüssigen Gebietstyps
ALTER TABLE schutzgebiet DROP COLUMN unterschutzstellungsdatum;
-- entfernen des nun überflüssigen Unterschutzstellungsdatums

-- Anlegen der Verknüpfungstabelle:
CREATE TABLE schutzgebiet_hat_gebietstyp
(
schutzgebiet_gid integer NOT NULL,
-- Feld für die Referenz auf schutzgebiet.gid
gebietstyp_id integer NOT NULL,
-- Feld für die Referenz auf gebietstyp.id
unterschutzstellungsdatum date NOT NULL DEFAULT ('now'::text)::date,
CONSTRAINT "schutzgebiet_hat_gebietstyp_pkey" PRIMARY KEY (schutzgebiet_gid, gebietstyp_id),
-- kombinierter Primärschlüssel: die Kombination aus beiden macht den Datensatz identifizierbar
CONSTRAINT "fk_schutzgebiet_hat_gebietstyp_schutzgebiet" FOREIGN KEY (schutzgebiet_gid)
      REFERENCES schutzgebiet (gid) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE CASCADE,
-- referenzielle Integrität auf schutzgebiet.gid; wenn das Schutzgebiet gelöscht wird, wird auch
-- der Eintrag in der Verknüpfungstabelle gelöscht (ON DELETE CASCADE)
CONSTRAINT "fk_schutzgebiet_hat_gebietstyp_gebietstyp" FOREIGN KEY (gebietstyp_id)
      REFERENCES gebietstyp (id) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE RESTRICT
-- refernzielle Integrität auf den Gebietstyp, wird der Gebietstyp gelöscht, wird dies verhindert,
-- solange in der Verknüpfungstabelle noch Schutzgebiete mit ihm verknüpft sind (ON DELETE RESTRICT)
);
CREATE INDEX schutzgebiet_idx ON schutzgebiet_hat_gebietstyp (schutzgebiet_gid);
CREATE INDEX gebietstyp_idx ON schutzgebiet_hat_gebietstyp (gebietstyp_id);
-- Indizes auf Fremdschlüssel anlegen

/* FFFFFFFFFFFFFFFFFFFFF */
CREATE TABLE  kontrolleur (
  id INTEGER NOT NULL,
  kontrolleur VARCHAR(64) NOT NULL,
  PRIMARY KEY (id));
  
CREATE TABLE kontrolle (
  id serial NOT NULL,
  schutzgebiet_gid INTEGER NOT NULL,
  kontrolleur_id INTEGER NOT NULL,
  kontrolldatum DATE NOT NULL DEFAULT current_date,
  massnahmen_erforderlich BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (id),
  CONSTRAINT fk_kontrolle_kontrolleur1
    FOREIGN KEY (kontrolleur_id)
    REFERENCES kontrolleur (id)
    ON DELETE NO ACTION
    ON UPDATE CASCADE,
  CONSTRAINT fk_kontrolle_schutzgebiet1
    FOREIGN KEY (schutzgebiet_gid)
    REFERENCES schutzgebiet (gid)
    ON DELETE CASCADE
    ON UPDATE CASCADE);

CREATE INDEX idx_fk_kontrolle_kontrolleur1_idx ON kontrolle (kontrolleur_id);
CREATE INDEX idx_fk_kontrolle_Schutzgebiet1_idx ON kontrolle (schutzgebiet_gid);

CREATE TABLE arten (
  id INTEGER NOT NULL,
  artname VARCHAR(64) NOT NULL,
  PRIMARY KEY (id));

CREATE TABLE  kontrolle_findet_arten (
  kontrolle_id INTEGER NOT NULL,
  arten_id INTEGER NOT NULL,
  PRIMARY KEY (kontrolle_id, arten_id),
  CONSTRAINT fk_kontrolle_findet_arten_kontrolle1
    FOREIGN KEY (kontrolle_id)
    REFERENCES kontrolle (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_kontrolle_findet_arten_arten1
    FOREIGN KEY (arten_id)
    REFERENCES arten (id)
    ON DELETE NO ACTION
    ON UPDATE CASCADE);

CREATE INDEX idx_fk_kontrolle_arten1_idx ON kontrolle_findet_arten (arten_id);
CREATE INDEX idx_fk_kontrolle_kontrolle1_idx ON kontrolle_findet_arten (kontrolle_id);

INSERT INTO kontrolleur (id, kontrolleur) VALUES (1, 'Müller');
INSERT INTO kontrolleur (id, kontrolleur) VALUES (2, 'Maier');
INSERT INTO kontrolleur (id, kontrolleur) VALUES (3, 'Schulze');

INSERT INTO arten (id, artname) VALUES (1, 'geoserver');
INSERT INTO arten (id, artname) VALUES (2, 'OpenLayers 3');
INSERT INTO arten (id, artname) VALUES (3, 'mapfish');
INSERT INTO arten (id, artname) VALUES (4, 'QGIS Server');
INSERT INTO arten (id, artname) VALUES (5, 'QGIS Desktop');
INSERT INTO arten (id, artname) VALUES (6, 'QGIS Webclient');
  
  
  
  
  