import os
import struct
import numpy as np
import trimesh
from tkinter import Tk, Label, Entry, Button, filedialog, messagebox, StringVar
from PIL import Image

# --- Fonctions d'analyse et de conversion du format PET ---

class PETWriter:
    """Classe pour écrire des fichiers .PET de Pangya avec la structure complète"""

    def __init__(self):
        self.data = bytearray()

    def write_section(self, fourcc, data):
        """Écrit une section avec FourCC et longueur"""
        header = struct.pack('<4sI', fourcc.encode('ascii'), len(data))
        self.data += header + data

    def write_vers_section(self):
        """Section VERS (Version) - 4 bytes"""
        # Format: 03 01 FE FF
        vers_data = struct.pack('<BBBB', 0x03, 0x01, 0xFE, 0xFF)
        self.write_section('VERS', vers_data)

    def write_text_section(self, texture_name):
        """
        Section TEXT (Texture) - Structure complexe
        Format: Compteur + 3 slots de texture (48 bytes chacun)
        Slot: Nom(40 bytes) + Flags(4 bytes) + Couleur(4 bytes)
        """
        texture_count = struct.pack('<I', 0x03)  # 3 textures

        # Slot 1: Texture principale
        slot1_name = texture_name.ljust(40, '\x00')
        slot1_flags = struct.pack('<I', 0x00200201)  # 01 02 00 20
        slot1_color = struct.pack('<BBBB', 0xF4, 0xE2, 0xDD, 0xFF)
        slot1 = slot1_name.encode('ascii') + slot1_flags + slot1_color

        # Slot 2: Texture secondaire (Ball_soni)
        slot2_name = "][2#_balltex_soni.jpg".ljust(40, '\x00')
        slot2_flags = struct.pack('<I', 0x00200401)  # 01 04 00 20
        slot2_color = struct.pack('<BBBB', 0x95, 0x95, 0x95, 0xFF)
        slot2 = slot2_name.encode('ascii') + slot2_flags + slot2_color

        # Slot 3: Texture spéculaire
        slot3_name = "!specular_ellipse_sm.jpg".ljust(40, '\x00')
        slot3_flags = struct.pack('<I', 0x20202001)  # 01 20 20 20
        slot3_color = struct.pack('<BBBB', 0xFF, 0xFF, 0xFF, 0xFF)
        slot3 = slot3_name.encode('ascii') + slot3_flags + slot3_color

        text_data = texture_count + slot1 + slot2 + slot3
        self.write_section('TEXT', text_data)

    def write_smtl_section(self, material_name="Ball_soni"):
        """
        Section SMTL (Material) - 4 bytes
        Matériau simplifié
        """
        # Juste l'en-tête minimal
        smtl_data = struct.pack('<I', 0x20202020)
        self.write_section('SMTL', smtl_data)

    def write_anim_section(self):
        """Section ANIM (Animation) - 1 byte"""
        anim_data = struct.pack('<B', 0xFF)
        self.write_section('ANIM', anim_data)

    def write_mesh_section(self, vertices, normals, uvs, faces):
        """
        Section MESH - Géométrie complète
        Format: Nombre de vertices + Vertices entrelacés + Faces
        Chaque vertex: Position(12) + Normal(12) + UV(8) + Flag(1) = 33 bytes
        """
        num_vertices = len(vertices)
        mesh_data = bytearray()

        # Nombre de vertices
        mesh_data += struct.pack('<I', num_vertices)

        # Vertices entrelacés avec le format correct
        for i in range(num_vertices):
            # Position (3 floats)
            mesh_data += struct.pack('<fff',
                                   vertices[i][0],
                                   vertices[i][1],
                                   vertices[i][2])

            # Normal (3 floats)
            if i < len(normals):
                mesh_data += struct.pack('<fff',
                                       normals[i][0],
                                       normals[i][1],
                                       normals[i][2])
            else:
                mesh_data += struct.pack('<fff', 0.0, 0.0, 1.0)

            # UV (2 floats)
            if i < len(uvs):
                mesh_data += struct.pack('<ff',
                                       uvs[i][0],
                                       uvs[i][1])
            else:
                mesh_data += struct.pack('<ff', 0.0, 0.0)

            # Flag (1 byte) - toujours 0xFF dans l'exemple
            mesh_data += struct.pack('<B', 0xFF)

        # Nombre de faces
        num_faces = len(faces)
        mesh_data += struct.pack('<I', num_faces)

        # Faces (indices)
        for face in faces:
            mesh_data += struct.pack('<III', face[0], face[1], face[2])

        self.write_section('MESH', mesh_data)

    def write_fanm_section(self, texture_name):
        """
        Section FANM (Frame Animation/Texture mapping)
        Cette section lie les textures aux matériaux
        """
        fanm_data = bytearray()

        # Nombre d'entrées (2)
        fanm_data += struct.pack('<I', 0x02)

        # Entrée 1
        entry1_idx = struct.pack('<I', 0x02)
        entry1_name = ('+2#_balltex_soni_01'.ljust(20, ' ')).encode('ascii')
        entry1_data = struct.pack('<I', 0x35)  # '5' + 'R' en ASCII
        entry1_separator = b'R \xff\xff\xff\xff'
        entry1_ref = b'R\xef L \xfc'
        entry1_file = ('+2#_balltex_soni_01.dds'.ljust(30, ' ')).encode('ascii')
        entry1_footer = b'ESH\x0e\x9f  m\x04'

        fanm_data += entry1_idx + entry1_name + entry1_data + entry1_separator
        fanm_data += entry1_ref + entry1_file + entry1_footer

        # Entrée 2
        entry2_name = ('][2#_balltex_soni'.ljust(20, ' ')).encode('ascii')
        entry2_data = struct.pack('<I', 0x31)  # '1' + ' '
        entry2_separator = b'5R \xff\xff\xff\xff'
        entry2_ref = b'R\xef L \xfc'
        entry2_file = ('][2#_balltex_soni.jpg'.ljust(30, ' ')).encode('ascii')
        entry2_footer = b's ESH\x0e\x9f  m'

        fanm_data += entry2_name + entry2_data + entry2_separator
        fanm_data += entry2_ref + entry2_file + entry2_footer

        self.write_section('FANM', fanm_data)

    def write_fram_section(self):
        """Section FRAM (Frame) - Structure d'animation basique"""
        fram_data = struct.pack('<I', 0x20202020)
        self.write_section('FRAM', fram_data)

    def write_moti_section(self):
        """Section MOTI (Motion) - Animation basique"""
        moti_data = struct.pack('<I', 0x20202020)
        self.write_section('MOTI', moti_data)

    def write_coll_section(self, material_name="Ball_soni"):
        """
        Section COLL (Collision) - Informations de collision
        Structure: compteur + entrées de collision
        """
        coll_data = bytearray()

        # Nombre d'entrées (2)
        coll_data += struct.pack('<I', 0x02)

        # Type (1)
        coll_data += struct.pack('<I', 0x01)

        # Count (1)
        coll_data += struct.pack('<I', 0x01)

        # Nombre de vertices collision (9)
        coll_data += struct.pack('<I', 0x09)

        # Nom du matériau
        mat_name = material_name.ljust(9, '\x00').encode('ascii')
        coll_data += mat_name

        # Répéter pour deuxième entrée
        coll_data += mat_name

        # Padding
        coll_data += b'\x20' * 8

        # Bounding box min
        coll_data += struct.pack('<fff', -0.0393701, -0.0393701, -0.0393701)

        # Bounding box max
        coll_data += struct.pack('<fff', 0.0393701, 0.0393701, 0.0393701)

        # Flags
        coll_data += struct.pack('<I', 0x01)
        coll_data += struct.pack('<I', 0x01)

        # Centre name
        center_name = "center".ljust(6, '\x00').encode('ascii')
        coll_data += center_name

        # Material name répété
        coll_data += mat_name

        # Padding final
        coll_data += b'\x20' * 8

        # Bounding box répété
        coll_data += struct.pack('<fff', -0.0393701, -0.0393701, -0.0393701)
        coll_data += struct.pack('<fff', 0.0393701, 0.0393701, 0.0393701)

        self.write_section('COLL', coll_data)

    def get_data(self):
        """Retourne les données PET complètes"""
        return bytes(self.data)


def convertir_en_pet_avance(obj_path, png_path, output_path_unused):
    """Convertit un fichier OBJ + texture en fichier PET de Pangya"""
    try:
        # --- 1. Lecture du Mesh (.OBJ) et de la Texture ---
        print(f"Chargement du mesh depuis {obj_path}...")
        mesh = trimesh.load_mesh(obj_path)

        print(f"Chargement de la texture depuis {png_path}...")
        Image.open(png_path)  # Vérifie la lecture

        # 1a. Récupération des Vertices
        vertices = mesh.vertices.astype(np.float32)
        print(f"  - {len(vertices)} vertices")

        # 1b. Récupération des Normales
        if not hasattr(mesh, 'vertex_normals') or mesh.vertex_normals is None or len(mesh.vertex_normals) == 0:
            mesh.apply_normals()
        normals = mesh.vertex_normals.astype(np.float32)
        print(f"  - {len(normals)} normales")

        # 1c. Récupération des UVs
        try:
            uvs = mesh.visual.uv.astype(np.float32)
            print(f"  - {len(uvs)} coordonnées UV")
        except AttributeError:
            print("  - Pas de coordonnées UV, utilisation de valeurs par défaut")
            uvs = np.zeros((len(vertices), 2), dtype=np.float32)

        # 1d. Récupération des Faces
        faces = mesh.faces.astype(np.uint32)
        print(f"  - {len(faces)} faces")

        # --- 2. Création du fichier PET ---
        print("\nCréation du fichier PET...")
        writer = PETWriter()

        # Nom de la texture (sans chemin)
        texture_name = '+2#_' + os.path.splitext(os.path.basename(png_path))[0]
        if len(texture_name) > 40:
            texture_name = texture_name[:40]

        # Écriture des sections dans l'ordre correct
        writer.write_vers_section()
        writer.write_text_section(texture_name)
        writer.write_smtl_section()
        writer.write_anim_section()
        writer.write_mesh_section(vertices, normals, uvs, faces)
        writer.write_fanm_section(texture_name)
        writer.write_fram_section()
        writer.write_moti_section()
        writer.write_coll_section()

        # --- 3. Écriture du fichier ---
        output_dir = os.path.dirname(obj_path)
        obj_base_name = os.path.splitext(os.path.basename(obj_path))[0]
        final_output_path = os.path.join(output_dir, f"{obj_base_name}.pet")

        print(f"\nÉcriture vers {final_output_path}...")
        with open(final_output_path, 'wb') as f:
            f.write(writer.get_data())

        print(f"✓ Conversion réussie !")
        print(f"  Fichier PET créé : {final_output_path}")
        print(f"  Taille : {len(writer.get_data())} bytes")

        messagebox.showinfo("Succès",
            f"Conversion réussie !\n\n"
            f"Fichier : {final_output_path}\n"
            f"Vertices : {len(vertices)}\n"
            f"Faces : {len(faces)}")

    except Exception as e:
        import traceback
        error_msg = f"Erreur pendant la conversion:\n{str(e)}\n\n{traceback.format_exc()}"
        print(error_msg)
        messagebox.showerror("Erreur", error_msg)


# --- Classe d'interface graphique (GUI) ---

class ConverterApp:
    def __init__(self, master):
        self.master = master
        master.title("Pangya .PET Converter - Version Améliorée")
        master.geometry("500x350")

        self.obj_path = StringVar()
        self.png_path = StringVar()

        # Titre
        Label(master, text="Pangya .PET Converter", font=("Arial", 14, "bold")).pack(pady=10)
        Label(master, text="Convertisseur .OBJ + Texture → .PET (Format complet)",
              font=("Arial", 9)).pack()

        # OBJ
        Label(master, text="Fichier .OBJ (Mesh 3D) :", font=("Arial", 10, "bold")).pack(pady=(15, 0))
        Entry(master, textvariable=self.obj_path, width=50).pack(pady=5)
        Button(master, text="📁 Parcourir OBJ...", command=self.select_obj, width=20).pack()

        # PNG/JPG (Texture)
        Label(master, text="Fichier Texture (.PNG ou .JPG) :", font=("Arial", 10, "bold")).pack(pady=(15, 0))
        Entry(master, textvariable=self.png_path, width=50).pack(pady=5)
        Button(master, text="📁 Parcourir Texture...", command=self.select_png, width=20).pack()

        # Bouton de conversion
        Button(master, text="🔄 Convertir en PET", bg="#4CAF50", fg="white",
               font=("Arial", 12, "bold"), command=self.convert, height=2).pack(pady=20)

        # Info
        Label(master, text="Version améliorée avec support complet du format PET",
              font=("Arial", 8), fg="gray").pack(side="bottom", pady=5)

    def select_obj(self):
        filename = filedialog.askopenfilename(
            title="Sélectionner le fichier OBJ",
            defaultextension=".obj",
            filetypes=[("Fichiers OBJ", "*.obj"), ("Tous les fichiers", "*.*")]
        )
        if filename:
            self.obj_path.set(filename)

    def select_png(self):
        filename = filedialog.askopenfilename(
            title="Sélectionner la texture",
            defaultextension=".png",
            filetypes=[
                ("Fichiers de Texture", "*.png;*.jpg;*.jpeg"),
                ("PNG files", "*.png"),
                ("JPEG files", "*.jpg;*.jpeg"),
                ("Tous les fichiers", "*.*")
            ]
        )
        if filename:
            self.png_path.set(filename)

    def convert(self):
        obj_p = self.obj_path.get()
        png_p = self.png_path.get()

        if not obj_p or not png_p:
            messagebox.showwarning("Attention",
                "Veuillez sélectionner un fichier OBJ et une texture !")
            return

        if not os.path.exists(obj_p):
            messagebox.showerror("Erreur", f"Le fichier OBJ n'existe pas:\n{obj_p}")
            return

        if not os.path.exists(png_p):
            messagebox.showerror("Erreur", f"Le fichier texture n'existe pas:\n{png_p}")
            return

        convertir_en_pet_avance(obj_p, png_p, "")


# --- Lancement de l'application ---
if __name__ == "__main__":
    print("=" * 60)
    print("Pangya .PET Converter - Version Améliorée")
    print("=" * 60)
    print()

    root = Tk()
    app = ConverterApp(root)
    root.mainloop()
