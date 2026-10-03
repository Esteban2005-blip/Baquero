from getpass import getpass
import oracledb

print("Iniciando prueba de Oracle...", flush=True)
password = getpass("Contraseña de BLOC_NOTAS_APP: ")

try:
    dsn = oracledb.makedsn("localhost", 1521, sid="orcl")

    with oracledb.connect(
        user="BLOC_NOTAS_APP",
        password=password,
        dsn=dsn
    ) as conexion:
        with conexion.cursor() as cursor:
            cursor.execute("SELECT USER FROM dual")
            print("Conexión correcta:", cursor.fetchone()[0])

            cursor.execute("""
                SELECT table_name
                FROM user_tables
                ORDER BY table_name
            """)

            for fila in cursor:
                print("Tabla:", fila[0])

except oracledb.Error as error:
    print("Error de conexión:", error)