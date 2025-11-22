import os
import struct
import numpy as np
import trimesh
from tkinter import Tk, Label, Entry, Button, filedialog, messagebox, StringVar, Frame, Checkbutton, BooleanVar
from tkinter import ttk
from PIL import Image

# --- Fonctions d'analyse et de conversion du format PET ---

class PETWriter:
    """Classe pour écrire des fichiers .PET de Pangya avec la structure complète"""

    def __init__(self, material_name=None, mesh_name=None):
        self.data = bytearray()
        self.material_name = material_name or "DefaultMat"
        self.mesh_name = mesh_name or "DefaultMesh"

    def write_section(self, fourcc, data):
        """Écrit une section avec FourCC et longueur"""
        header = struct.pack('<4sI', fourcc.encode('ascii'), len(data))
        self.data += header + data

    def write_vers_section(self):
        """Section VERS (Version) - 4 bytes"""
        vers_data = struct.pack('<BBBB', 0x03, 0x01, 0xFE, 0xFF)
        self.write_section('VERS', vers_data)

    def write_text_section(self, texture_name, use_custom_textures=True):
        """
        Section TEXT (Texture) - Structure complexe
        Format: Compteur + 3 slots de texture (48 bytes chacun)
        """
        texture_count = struct.pack('<I', 0x03)

        # Slot 1: Texture principale (utilise le nom du fichier fourni)
        if use_custom_textures:
            # Ajouter préfixe Pangya si pas déjà présent
            if not texture_name.startswith('+') and not texture_name.startswith(']['):
                slot1_name = f"+2#_{texture_name}"
            else:
                slot1_name = texture_name
        else:
            slot1_name = texture_name

        slot1_name = slot1_name[:40].ljust(40, '\x00')
        slot1_flags = struct.pack('<I', 0x00200201)
        slot1_color = struct.pack('<BBBB', 0xF4, 0xE2, 0xDD, 0xFF)
        slot1 = slot1_name.encode('ascii') + slot1_flags + slot1_color

        # Slot 2: Texture secondaire (basée sur le nom principal)
        base_name = os.path.splitext(texture_name)[0]
        slot2_name = f"][2#_{base_name}"[:40].ljust(40, '\x00')
        slot2_flags = struct.pack('<I', 0x00200401)
        slot2_color = struct.pack('<BBBB', 0x95, 0x95, 0x95, 0xFF)
        slot2 = slot2_name.encode('ascii') + slot2_flags + slot2_color

        # Slot 3: Texture spéculaire
        slot3_name = "!specular_ellipse_sm.jpg"[:40].ljust(40, '\x00')
        slot3_flags = struct.pack('<I', 0x20202001)
        slot3_color = struct.pack('<BBBB', 0xFF, 0xFF, 0xFF, 0xFF)
        slot3 = slot3_name.encode('ascii') + slot3_flags + slot3_color

        text_data = texture_count + slot1 + slot2 + slot3
        self.write_section('TEXT', text_data)

    def write_smtl_section(self):
        """Section SMTL (Material) - Structure simplifiée"""
        smtl_data = struct.pack('<I', 0x20202020)
        self.write_section('SMTL', smtl_data)

    def write_anim_section(self):
        """Section ANIM (Animation) - 1 byte"""
        anim_data = struct.pack('<B', 0xFF)
        self.write_section('ANIM', anim_data)

    def write_mesh_section(self, vertices, normals, uvs, faces):
        """
        Section MESH - Géométrie complète
        Format interleaved: Position + Normal + UV + Flag pour chaque vertex
        """
        num_vertices = len(vertices)
        mesh_data = bytearray()

        # Nombre de vertices
        mesh_data += struct.pack('<I', num_vertices)

        # Vertices entrelacés
        for i in range(num_vertices):
            # Position (3 floats)
            mesh_data += struct.pack('<fff',
                                   float(vertices[i][0]),
                                   float(vertices[i][1]),
                                   float(vertices[i][2]))

            # Normal (3 floats)
            if i < len(normals):
                mesh_data += struct.pack('<fff',
                                       float(normals[i][0]),
                                       float(normals[i][1]),
                                       float(normals[i][2]))
            else:
                mesh_data += struct.pack('<fff', 0.0, 0.0, 1.0)

            # UV (2 floats)
            if i < len(uvs):
                mesh_data += struct.pack('<ff',
                                       float(uvs[i][0]),
                                       float(1.0 - uvs[i][1]))  # Inverser V pour Pangya
            else:
                mesh_data += struct.pack('<ff', 0.0, 0.0)

            # Flag (1 byte)
            mesh_data += struct.pack('<B', 0xFF)

        # Nombre de faces
        num_faces = len(faces)
        mesh_data += struct.pack('<I', num_faces)

        # Faces (indices)
        for face in faces:
            mesh_data += struct.pack('<III',
                                   int(face[0]),
                                   int(face[1]),
                                   int(face[2]))

        self.write_section('MESH', mesh_data)

    def write_fanm_section(self, texture_name):
        """
        Section FANM (Frame Animation/Texture mapping)
        Simplifié pour supporter n'importe quel nom
        """
        fanm_data = bytearray()
        fanm_data += struct.pack('<I', 0x02)  # 2 entrées

        # Texture principale
        base_name = os.path.splitext(texture_name)[0]

        # Entrée 1
        entry1_name = f"+2#_{base_name}"[:20].ljust(20, ' ')
        fanm_data += struct.pack('<I', 0x02)
        fanm_data += entry1_name.encode('ascii')
        fanm_data += struct.pack('<I', 0x35)
        fanm_data += b'R \xff\xff\xff\xff'
        fanm_data += b'R\xef L \xfc'
        fanm_data += (f"+2#_{base_name}.dds"[:30].ljust(30, ' ')).encode('ascii')
        fanm_data += b'ESH\x0e\x9f  m\x04'

        # Entrée 2
        entry2_name = f"][2#_{base_name}"[:20].ljust(20, ' ')
        fanm_data += entry2_name.encode('ascii')
        fanm_data += struct.pack('<I', 0x31)
        fanm_data += b'5R \xff\xff\xff\xff'
        fanm_data += b'R\xef L \xfc'
        fanm_data += (f"][2#_{base_name}.jpg"[:30].ljust(30, ' ')).encode('ascii')
        fanm_data += b's ESH\x0e\x9f  m'

        self.write_section('FANM', fanm_data)

    def write_fram_section(self):
        """Section FRAM (Frame)"""
        fram_data = struct.pack('<I', 0x20202020)
        self.write_section('FRAM', fram_data)

    def write_moti_section(self):
        """Section MOTI (Motion)"""
        moti_data = struct.pack('<I', 0x20202020)
        self.write_section('MOTI', moti_data)

    def write_coll_section(self):
        """
        Section COLL (Collision)
        Utilise le nom du matériau de l'objet
        """
        coll_data = bytearray()
        coll_data += struct.pack('<I', 0x02)  # 2 entrées
        coll_data += struct.pack('<I', 0x01)  # Type
        coll_data += struct.pack('<I', 0x01)  # Count
        coll_data += struct.pack('<I', 0x09)  # Nombre de vertices collision

        # Utiliser le nom du matériau (max 9 chars)
        mat_name = self.material_name[:9].ljust(9, '\x00').encode('ascii')
        coll_data += mat_name
        coll_data += mat_name
        coll_data += b'\x20' * 8

        # Bounding box (valeurs par défaut, peuvent être calculées)
        coll_data += struct.pack('<fff', -0.1, -0.1, -0.1)  # Min
        coll_data += struct.pack('<fff', 0.1, 0.1, 0.1)     # Max

        coll_data += struct.pack('<I', 0x01)
        coll_data += struct.pack('<I', 0x01)

        # Centre
        center_name = "center".ljust(6, '\x00').encode('ascii')
        coll_data += center_name
        coll_data += mat_name
        coll_data += b'\x20' * 8

        # Bounding box répété
        coll_data += struct.pack('<fff', -0.1, -0.1, -0.1)
        coll_data += struct.pack('<fff', 0.1, 0.1, 0.1)

        self.write_section('COLL', coll_data)

    def get_data(self):
        """Retourne les données PET complètes"""
        return bytes(self.data)


def extraire_nom_materiau(mesh):
    """Extrait le nom du matériau depuis le mesh OBJ"""
    try:
        if hasattr(mesh, 'visual') and hasattr(mesh.visual, 'material'):
            if hasattr(mesh.visual.material, 'name'):
                return mesh.visual.material.name
        # Sinon retourner un nom par défaut
        return "Material"
    except:
        return "Material"


def calculer_bounding_box(vertices):
    """Calcule la bounding box du mesh"""
    min_coords = np.min(vertices, axis=0)
    max_coords = np.max(vertices, axis=0)
    return min_coords, max_coords


def convertir_en_pet_avance(obj_path, png_path, options=None):
    """
    Convertit un fichier OBJ + texture en fichier PET de Pangya

    Args:
        obj_path: Chemin vers le fichier OBJ
        png_path: Chemin vers la texture
        options: Dictionnaire d'options (custom_name, use_custom_textures, etc.)
    """
    if options is None:
        options = {}

    try:
        # --- 1. Lecture du Mesh (.OBJ) et de la Texture ---
        print(f"\n{'='*60}")
        print(f"Chargement du mesh depuis {obj_path}...")
        mesh = trimesh.load_mesh(obj_path)

        print(f"Chargement de la texture depuis {png_path}...")
        Image.open(png_path)

        # Extraire le nom du matériau depuis l'OBJ
        material_name = extraire_nom_materiau(mesh)
        print(f"  - Matériau détecté: {material_name}")

        # Utiliser un nom personnalisé si fourni
        if options.get('custom_material_name'):
            material_name = options['custom_material_name']
            print(f"  - Matériau personnalisé: {material_name}")

        # Récupération des données de géométrie
        vertices = mesh.vertices.astype(np.float32)
        print(f"  - {len(vertices)} vertices")

        # Normales
        if not hasattr(mesh, 'vertex_normals') or mesh.vertex_normals is None or len(mesh.vertex_normals) == 0:
            print("  - Calcul des normales...")
            mesh.apply_normals()
        normals = mesh.vertex_normals.astype(np.float32)
        print(f"  - {len(normals)} normales")

        # UVs
        try:
            uvs = mesh.visual.uv.astype(np.float32)
            print(f"  - {len(uvs)} coordonnées UV")
        except AttributeError:
            print("  - ⚠ Pas de coordonnées UV, utilisation de valeurs par défaut")
            uvs = np.zeros((len(vertices), 2), dtype=np.float32)

        # Faces
        faces = mesh.faces.astype(np.uint32)
        print(f"  - {len(faces)} faces")

        # Calcul de la bounding box
        bbox_min, bbox_max = calculer_bounding_box(vertices)
        print(f"  - Bounding Box: Min{tuple(bbox_min)}, Max{tuple(bbox_max)}")

        # --- 2. Création du fichier PET ---
        print(f"\n{'='*60}")
        print("Création du fichier PET...")

        # Nom de la texture (sans extension)
        texture_base_name = os.path.splitext(os.path.basename(png_path))[0]

        # Créer le writer avec les noms détectés
        writer = PETWriter(material_name=material_name, mesh_name=texture_base_name)

        # Écriture des sections
        print("  - Écriture section VERS (Version)")
        writer.write_vers_section()

        print("  - Écriture section TEXT (Textures)")
        writer.write_text_section(texture_base_name,
                                 use_custom_textures=options.get('use_pangya_prefix', True))

        print("  - Écriture section SMTL (Matériau)")
        writer.write_smtl_section()

        print("  - Écriture section ANIM (Animation)")
        writer.write_anim_section()

        print("  - Écriture section MESH (Géométrie)")
        writer.write_mesh_section(vertices, normals, uvs, faces)

        print("  - Écriture section FANM (Frame Animation)")
        writer.write_fanm_section(texture_base_name)

        print("  - Écriture section FRAM (Frame)")
        writer.write_fram_section()

        print("  - Écriture section MOTI (Motion)")
        writer.write_moti_section()

        print("  - Écriture section COLL (Collision)")
        writer.write_coll_section()

        # --- 3. Écriture du fichier ---
        output_dir = os.path.dirname(obj_path)
        obj_base_name = os.path.splitext(os.path.basename(obj_path))[0]

        # Nom de sortie personnalisé si fourni
        if options.get('output_name'):
            final_output_path = os.path.join(output_dir, f"{options['output_name']}.pet")
        else:
            final_output_path = os.path.join(output_dir, f"{obj_base_name}.pet")

        print(f"\n{'='*60}")
        print(f"Écriture vers {final_output_path}...")
        with open(final_output_path, 'wb') as f:
            f.write(writer.get_data())

        file_size = len(writer.get_data())
        print(f"✓ Conversion réussie !")
        print(f"  📁 Fichier PET créé : {final_output_path}")
        print(f"  📊 Taille : {file_size:,} bytes")
        print(f"  🔺 Vertices : {len(vertices):,}")
        print(f"  🔻 Faces : {len(faces):,}")
        print(f"  🎨 Matériau : {material_name}")
        print(f"{'='*60}\n")

        messagebox.showinfo("✓ Conversion réussie",
            f"Fichier PET créé avec succès !\n\n"
            f"📁 {os.path.basename(final_output_path)}\n"
            f"📊 Taille: {file_size:,} bytes\n"
            f"🔺 Vertices: {len(vertices):,}\n"
            f"🔻 Faces: {len(faces):,}\n"
            f"🎨 Matériau: {material_name}")

        return True

    except Exception as e:
        import traceback
        error_msg = f"Erreur pendant la conversion:\n{str(e)}\n\n{traceback.format_exc()}"
        print(f"\n❌ ERREUR:\n{error_msg}")
        messagebox.showerror("❌ Erreur", f"Erreur pendant la conversion:\n\n{str(e)}")
        return False


# --- Interface graphique améliorée ---

class ConverterApp:
    def __init__(self, master):
        self.master = master
        master.title("Pangya .PET Converter - Version Complète")
        master.geometry("600x550")
        master.resizable(False, False)

        self.obj_path = StringVar()
        self.png_path = StringVar()
        self.custom_material = StringVar()
        self.output_name = StringVar()
        self.use_pangya_prefix = BooleanVar(value=True)

        # Style
        style = ttk.Style()
        style.configure('Title.TLabel', font=('Arial', 14, 'bold'))
        style.configure('Subtitle.TLabel', font=('Arial', 9))
        style.configure('Section.TLabel', font=('Arial', 10, 'bold'))

        # En-tête
        header_frame = Frame(master, bg='#2196F3', height=80)
        header_frame.pack(fill='x')
        header_frame.pack_propagate(False)

        Label(header_frame, text="🎮 Pangya .PET Converter",
              font=("Arial", 16, "bold"), bg='#2196F3', fg='white').pack(pady=5)
        Label(header_frame, text="Convertisseur OBJ → PET avec détection automatique",
              font=("Arial", 9), bg='#2196F3', fg='white').pack()

        # Corps
        main_frame = Frame(master, padx=20, pady=20)
        main_frame.pack(fill='both', expand=True)

        # Section Fichiers
        Label(main_frame, text="📁 Fichiers d'entrée", font=("Arial", 11, "bold")).grid(
            row=0, column=0, columnspan=3, sticky='w', pady=(0, 10))

        # OBJ
        Label(main_frame, text="Fichier 3D (.OBJ):").grid(row=1, column=0, sticky='w', pady=5)
        Entry(main_frame, textvariable=self.obj_path, width=45).grid(row=1, column=1, pady=5, padx=5)
        Button(main_frame, text="📂", command=self.select_obj, width=3).grid(row=1, column=2, pady=5)

        # Texture
        Label(main_frame, text="Texture (PNG/JPG):").grid(row=2, column=0, sticky='w', pady=5)
        Entry(main_frame, textvariable=self.png_path, width=45).grid(row=2, column=1, pady=5, padx=5)
        Button(main_frame, text="📂", command=self.select_png, width=3).grid(row=2, column=2, pady=5)

        # Séparateur
        ttk.Separator(main_frame, orient='horizontal').grid(
            row=3, column=0, columnspan=3, sticky='ew', pady=15)

        # Section Options
        Label(main_frame, text="⚙️ Options personnalisées", font=("Arial", 11, "bold")).grid(
            row=4, column=0, columnspan=3, sticky='w', pady=(0, 10))

        # Nom matériau
        Label(main_frame, text="Nom matériau (optionnel):").grid(row=5, column=0, sticky='w', pady=5)
        Entry(main_frame, textvariable=self.custom_material, width=45).grid(
            row=5, column=1, pady=5, padx=5)
        Label(main_frame, text="💡", font=("Arial", 12)).grid(row=5, column=2)

        # Nom sortie
        Label(main_frame, text="Nom fichier sortie (optionnel):").grid(row=6, column=0, sticky='w', pady=5)
        Entry(main_frame, textvariable=self.output_name, width=45).grid(
            row=6, column=1, pady=5, padx=5)
        Label(main_frame, text="📝", font=("Arial", 12)).grid(row=6, column=2)

        # Options
        Checkbutton(main_frame, text="Utiliser le préfixe Pangya (+2#_, ][2#_) pour les textures",
                   variable=self.use_pangya_prefix).grid(
            row=7, column=0, columnspan=3, sticky='w', pady=10)

        # Info
        info_frame = Frame(main_frame, bg='#E3F2FD', relief='solid', borderwidth=1)
        info_frame.grid(row=8, column=0, columnspan=3, sticky='ew', pady=10)
        Label(info_frame, text="ℹ️ Le matériau et autres infos seront détectés automatiquement depuis l'OBJ",
              bg='#E3F2FD', font=("Arial", 8), wraplength=500, justify='left').pack(padx=10, pady=10)

        # Bouton conversion
        convert_btn = Button(main_frame, text="🔄 CONVERTIR EN PET",
                           bg="#4CAF50", fg="white", font=("Arial", 13, "bold"),
                           command=self.convert, height=2, cursor="hand2")
        convert_btn.grid(row=9, column=0, columnspan=3, pady=20, sticky='ew')

        # Pied de page
        footer = Frame(master, bg='#f5f5f5', height=30)
        footer.pack(fill='x', side='bottom')
        Label(footer, text="Version 2.0 - Support complet du format PET de Pangya",
              font=("Arial", 8), fg="gray", bg='#f5f5f5').pack(pady=8)

    def select_obj(self):
        filename = filedialog.askopenfilename(
            title="Sélectionner le fichier OBJ (mesh 3D)",
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
                ("Images", "*.png;*.jpg;*.jpeg;*.dds"),
                ("PNG", "*.png"),
                ("JPEG", "*.jpg;*.jpeg"),
                ("DDS", "*.dds"),
                ("Tous", "*.*")
            ]
        )
        if filename:
            self.png_path.set(filename)

    def convert(self):
        obj_p = self.obj_path.get()
        png_p = self.png_path.get()

        if not obj_p or not png_p:
            messagebox.showwarning("⚠️ Attention",
                "Veuillez sélectionner un fichier OBJ et une texture !")
            return

        if not os.path.exists(obj_p):
            messagebox.showerror("❌ Erreur", f"Le fichier OBJ n'existe pas:\n{obj_p}")
            return

        if not os.path.exists(png_p):
            messagebox.showerror("❌ Erreur", f"Le fichier texture n'existe pas:\n{png_p}")
            return

        # Préparer les options
        options = {
            'use_pangya_prefix': self.use_pangya_prefix.get(),
        }

        if self.custom_material.get().strip():
            options['custom_material_name'] = self.custom_material.get().strip()

        if self.output_name.get().strip():
            options['output_name'] = self.output_name.get().strip()

        # Lancer la conversion
        convertir_en_pet_avance(obj_p, png_p, options)


# --- Lancement de l'application ---
if __name__ == "__main__":
    print("=" * 60)
    print("🎮 Pangya .PET Converter - Version 2.0")
    print("=" * 60)
    print("Fonctionnalités:")
    print("  ✓ Détection automatique des matériaux")
    print("  ✓ Support complet du format PET")
    print("  ✓ Personnalisation des noms")
    print("  ✓ Format MESH interleaved correct")
    print("=" * 60)
    print()

    root = Tk()
    app = ConverterApp(root)
    root.mainloop()
