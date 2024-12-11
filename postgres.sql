-- Tabla de Usuarios
CREATE TABLE Usuario (
    id_usuario SERIAL PRIMARY KEY,
    nombre_usuario VARCHAR(50) UNIQUE NOT NULL,
    contrasena VARCHAR(255) NOT NULL,  -- Asegúrate de guardar la contraseña de manera segura
    rol VARCHAR(20) CHECK (rol IN ('miembro', 'empleado', 'administrador')) NOT NULL
);

-- Tabla de Libros
CREATE TABLE Libro (
    id_libro SERIAL PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    isbn VARCHAR(20)  NOT NULL,
    anio_publicacion INT CHECK (anio_publicacion > 0),
    autor VARCHAR(200) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    cantidad_total INT CHECK (cantidad_total >= 0),
    cantidad_disponible INT CHECK (cantidad_disponible >= 0)
);

-- Tabla de Miembros
CREATE TABLE Miembro (
    id_miembro SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    direccion VARCHAR(200),
    telefono VARCHAR(20),
    email VARCHAR(100) UNIQUE
);

-- Tabla de Préstamos
CREATE TABLE Prestamo (
    id_prestamo SERIAL PRIMARY KEY,
    id_libro INT REFERENCES Libro(id_libro),
    id_miembro INT REFERENCES Miembro(id_miembro),
    fecha_prestamo DATE NOT NULL,
    fecha_devolucion DATE,
    estado_prestamo VARCHAR(20) CHECK (estado_prestamo IN ('pendiente', 'finalizado', 'en proceso'))
);

-- Tabla de Devoluciones
CREATE TABLE Devolucion (
    id_devolucion SERIAL PRIMARY KEY,
    id_prestamo INT REFERENCES Prestamo(id_prestamo),
    fecha_devolucion DATE NOT NULL,
    estado_devolucion VARCHAR(20) CHECK (estado_devolucion IN ('Devuelto', 'Retornado'))
);

-- Tabla de Reservas
CREATE TABLE Reserva (
    id_reserva SERIAL PRIMARY KEY,
    id_libro INT REFERENCES Libro(id_libro),
    id_miembro INT REFERENCES Miembro(id_miembro),
    fecha_reserva DATE NOT NULL,
    fecha_caducidad DATE NOT NULL,
    estado_miembro VARCHAR(20) CHECK (estado_miembro IN ('Activa', 'Cancelada'))
);

-- Crear roles de base de datos (Para permisos de acceso)
CREATE ROLE miembro;
CREATE ROLE empleado;
CREATE ROLE administrador;

-- Permisos de acceso para el rol "miembro"
ALTER TABLE Miembro ENABLE ROW LEVEL SECURITY; -- RLS permite definir políticas basadas en las características de la fila y el contexto del usuario

CREATE POLICY Up_datos -- Identificar al miembro actual mediante un atributo
ON Miembro
FOR UPDATE
USING (email = current_user);

GRANT UPDATE ON Miembro TO miembro; -- Otorgar permisos de actualización al rol miembro
GRANT SELECT ON Libro TO miembro; -- Ver los libros
GRANT INSERT ON Reserva TO miembro; -- Hacer reservas

CREATE VIEW Vestado_prestamo AS
SELECT id_prestamo, estado_prestamo -- Crear la vista limitada
FROM Prestamo;

GRANT SELECT ON Vestado_prestamo TO miembro; -- Asignar permisos a la vista
REVOKE ALL ON Prestamo FROM miembro; -- Asegurar que el rol miembro no pueda acceder a otras columnas o modificar datos de la tabla Prestamo

CREATE VIEW Vestado_devolucion AS
SELECT id_devolucion, estado_devolucion -- Crear la vista limitada
FROM Devolucion;

GRANT SELECT ON Vestado_devolucion TO miembro; -- Asignar permisos a la vista
REVOKE ALL ON Devolucion FROM miembro; -- Asegurar que el rol miembro no pueda acceder a otras columnas o modificar datos de la tabla Devolucion

-- Permisos de acceso para el rol "empleado"
GRANT SELECT ON ALL TABLES IN SCHEMA public TO empleado; -- Otorgar permisos de lectura a todas las tablas
GRANT UPDATE, DELETE ON Libro TO empleado;-- Permisos de actualización para la tabla Libro
GRANT UPDATE ON Devolucion TO empleado; --Actualizar registros de la tabla Devolucion
GRANT UPDATE ON Reserva TO empleado; --Actualizar registros de la tabla Reserva

-- Permisos de acceso para el rol "administrador"
GRANT ALL PRIVILEGES ON DATABASE "Gestion de Biblioteca I" TO administrador;

-- Triggers y funciones

-- Trigger para actualizar cantidad_disponible en préstamos
CREATE OR REPLACE FUNCTION actualizar_cantidad_disponible_prestamo()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.estado_prestamo = 'en proceso' OR NEW.estado_prestamo = 'pendiente') THEN
        UPDATE Libro
        SET cantidad_disponible = cantidad_disponible - 1
        WHERE id_libro = NEW.id_libro;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_cantidad_disponible_prestamo
AFTER UPDATE ON Prestamo
FOR EACH ROW
EXECUTE FUNCTION actualizar_cantidad_disponible_prestamo();

-- Trigger para actualizar cantidad_disponible al devolver un libro
CREATE OR REPLACE FUNCTION actualizar_cantidad_disponible_devolucion()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Libro
    SET cantidad_disponible = cantidad_disponible + 1
    WHERE id_libro = (SELECT id_libro FROM Prestamo WHERE id_prestamo = NEW.id_prestamo);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_cantidad_disponible_devolucion
AFTER INSERT ON Devolucion
FOR EACH ROW
EXECUTE FUNCTION actualizar_cantidad_disponible_devolucion();

-- Trigger para cambiar el estado del préstamo al devolver un libro
CREATE OR REPLACE FUNCTION actualizar_estado_prestamo()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Prestamo
    SET estado_prestamo = 'finalizado'
    WHERE id_prestamo = NEW.id_prestamo;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_estado_prestamo
AFTER INSERT ON Devolucion
FOR EACH ROW
EXECUTE FUNCTION actualizar_estado_prestamo();

-- INSERTS
INSERT INTO Usuario (nombre_usuario, contrasena, rol) VALUES
('admin', 'admin123', 'administrador'),
('empleado1', 'empleado123', 'empleado'),
('miembro1', 'miembro123', 'miembro');

INSERT INTO Libro (titulo, isbn, anio_publicacion, autor, categoria, cantidad_total, cantidad_disponible) VALUES
('Cien años de soledad', '978-84-376-0494-7', 1967, 'Gabriel García Márquez', 'Novela', 10, 8),
('Harry Potter y el prisionero de Azkaban', '978-0-7475-3269-9', 1999, 'J.K. Rowling', 'Fantasía', 15, 12),
('El Señor de los Anillos: La Comunidad del Anillo', '978-0-261-10236-2', 1954, 'J.R.R. Tolkien', 'Fantasía', 20, 18),
('1984', '978-0-452-28423-4', 1949, 'George Orwell', 'Ciencia Ficción', 10, 5),
('La casa de los espíritus', '978-0-553-27352-8', 1982, 'Isabel Allende', 'Novela', 8, 6),
('Orgullo y prejuicio', '978-0-141-43995-3', 1813, 'Jane Austen', 'Romance', 12, 9),
('El Aleph', '978-84-663-4442-4', 1949, 'Julio Cortázar', 'Clásicos', 5, 3),
('Tokio Blues', '978-84-339-6937-6', 1987, 'Haruki Murakami', 'Novela', 7, 4),
('El cuento de la criada', '978-0-7710-0868-0', 1985, 'Margaret Atwood', 'Ciencia Ficción', 12, 10),
('Conversación en la Catedral', '978-84-376-1234-7', 1969, 'Mario Vargas Llosa', 'Novela', 6, 6);

INSERT INTO Miembro (nombre, apellido, direccion, telefono, email) VALUES
('Juan', 'Pérez', 'Calle Falsa 123', '555-1234', 'juan.perez@example.com'),
('Ana', 'Gómez', 'Av. Siempre Viva 456', '555-5678', 'ana.gomez@example.com'),
('Luis', 'Martínez', 'Calle Principal 789', '555-9101', 'luis.martinez@example.com'),
('María', 'López', 'Pasaje del Sol 12', '555-1111', 'maria.lopez@example.com'),
('Carlos', 'Ramírez', 'Barrio Central 34', '555-2222', 'carlos.ramirez@example.com'),
('Sofía', 'Hernández', 'Villa Bonita 56', '555-3333', 'sofia.hernandez@example.com'),
('Elena', 'Castro', 'Callejón Azul 78', '555-4444', 'elena.castro@example.com'),
('Tomás', 'Vargas', 'Plaza Roja 90', '555-5555', 'tomas.vargas@example.com'),
('Laura', 'Fernández', 'Calle Jardines 101', '555-6666', 'laura.fernandez@example.com'),
('Diego', 'Morales', 'Avenida Blanca 202', '555-7777', 'diego.morales@example.com');

INSERT INTO Prestamo (id_libro, id_miembro, fecha_prestamo, fecha_devolucion, estado_prestamo) VALUES
(1, 1, '2024-11-01', '2024-11-10', 'finalizado'),
(2, 2, '2024-11-05', NULL, 'en proceso'),
(3, 3, '2024-11-08', NULL, 'pendiente'),
(4, 4, '2024-11-15', NULL, 'en proceso'),
(5, 5, '2024-11-12', NULL, 'pendiente'),
(6, 6, '2024-11-03', '2024-11-18', 'finalizado'),
(7, 7, '2024-11-04', NULL, 'pendiente'),
(8, 8, '2024-11-10', NULL, 'en proceso'),
(9, 9, '2024-11-12', NULL, 'en proceso');

INSERT INTO Devolucion (id_prestamo, fecha_devolucion, estado_devolucion) VALUES
(6, '2024-11-18', 'Devuelto');

INSERT INTO Reserva (id_libro, id_miembro, fecha_reserva, fecha_caducidad, estado_miembro) VALUES
(1, 1, '2024-11-01', '2024-11-15', 'Activa'),
(2, 2, '2024-11-02', '2024-11-16', 'Activa'),
(3, 3, '2024-11-03', '2024-11-17', 'Cancelada'),
(4, 4, '2024-11-04', '2024-11-18', 'Activa'),
(5, 5, '2024-11-05', '2024-11-19', 'Cancelada'),
(6, 6, '2024-11-06', '2024-11-20', 'Activa'),
(7, 7, '2024-11-07', '2024-11-21', 'Activa'),
(8, 8, '2024-11-08', '2024-11-22', 'Cancelada'),
(9, 9, '2024-11-09', '2024-11-23', 'Activa'),
(10, 10, '2024-11-10', '2024-11-24', 'Activa');
