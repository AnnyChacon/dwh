﻿drop function if exists inventario_hechos();
CREATE OR REPLACE FUNCTION inventario_hechos() RETURNS SETOF RECORD AS $$

DECLARE 
    rent_cursor CURSOR FOR
    select t.fecha, p.idpelicula, count(*) 
    from rental r
    join inventory i on r.inventory_id = i.inventory_id
    join dwh.tiempo t on r.rental_date::date = t.fecha
    join dwh.pelicula p on i.film_id = p.idpelicula
    group by t.fecha, p.idpelicula order by t.fecha,p.idpelicula;
    v_fecha TIMESTAMP;
    v_idpelicula INTEGER;
    v_alquileres INTEGER;
    v_rentadas INTEGER;
    v_disponible INTEGER;
    v_total INTEGER;
    v_proporcion INTEGER;
    v_incidencias INTEGER;
    row RECORD;
BEGIN
    OPEN rent_cursor;
    LOOP
     FETCH rent_cursor INTO v_fecha,v_idpelicula,v_alquileres;
     EXIT WHEN NOT FOUND;
     
     --Para calcular el total de copias en inventario
     SELECT COUNT(*) INTO v_total FROM inventory i WHERE i.film_id=v_idpelicula;
     
     --Para calcular cuantas estan rentadas en el momento y poder calcular las disponibles: Total-rentadas
     SELECT COUNT(*) INTO v_rentadas FROM rental r JOIN inventory i on r.inventory_id = i.inventory_id AND i.film_id=v_idpelicula
     WHERE r.rental_date::date<=v_fecha and (r.return_date::date>v_fecha OR r.return_date is null);
     
     --Calcular cuantas veces al rentar una pelicula en un determinado dia, estaba sin stock 3 horas antes
     SELECT COUNT(*) FILTER (
         WHERE 
     	(v_total-
            (SELECT COUNT(*) FROM rental ren JOIN inventory inv on ren.inventory_id = inv.inventory_id AND inv.film_id=v_idpelicula
                WHERE ren.rental_date<=r.rental_date-interval '3 hours' and (ren.return_date>r.rental_date-interval '3 hours' OR ren.return_date is null)
            )
        )=0) INTO v_incidencias 
     FROM rental r JOIN inventory i on r.inventory_id = i.inventory_id AND i.film_id=v_idpelicula
     WHERE r.rental_date::date=v_fecha group by r.rental_date::date,i.film_id;
     
     --Se retorna la primera fila
     
     SELECT v_fecha::date, v_idpelicula, v_alquileres, (v_total-v_rentadas), round(v_alquileres::decimal/v_total,2), v_incidencias into row;
      RETURN next row;
     END LOOP;
END;
$$ LANGUAGE plpgsql;