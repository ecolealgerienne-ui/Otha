import { useEffect, useState } from 'react';
import { LegalLayout } from './LegalLayout';
import { useLanguage } from '../i18n';

interface FAQItem {
  question: string;
  answer: string;
}

interface FAQCategory {
  title: string;
  icon: string;
  items: FAQItem[];
}

export function SupportPage() {
  const { language } = useLanguage();
  const [searchQuery, setSearchQuery] = useState('');
  const [activeItems, setActiveItems] = useState<Set<string>>(new Set());

  useEffect(() => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
    document.head.appendChild(link);
    return () => {
      document.head.removeChild(link);
    };
  }, []);

  const toggleItem = (id: string) => {
    setActiveItems(prev => {
      const newSet = new Set(prev);
      if (newSet.has(id)) {
        newSet.delete(id);
      } else {
        newSet.add(id);
      }
      return newSet;
    });
  };

  const content = {
    fr: {
      title: 'Centre d\'aide',
      subtitle: 'Trouvez rapidement des réponses à vos questions',
      searchPlaceholder: 'Rechercher une question...',
      contactTitle: 'Besoin d\'aide supplémentaire ?',
      contactSubtitle: 'Notre équipe est là pour vous accompagner',
      contactCards: [
        {
          icon: 'fa-envelope',
          title: 'Email',
          desc: 'Réponse sous 24h',
          link: 'mailto:support@vegece.com',
          linkText: 'support@vegece.com'
        },
        {
          icon: 'fa-phone',
          title: 'Téléphone',
          desc: 'Lun-Ven, 9h-18h',
          link: 'tel:+213XXXXXXXX',
          linkText: '+213 XX XX XX XX'
        },
        {
          icon: 'fa-comments',
          title: 'Chat en direct',
          desc: 'Disponible dans l\'app',
          link: '#',
          linkText: 'Ouvrir le chat'
        }
      ],
      faq: [
        {
          title: 'Compte & Inscription',
          icon: 'fa-user-circle',
          items: [
            {
              question: 'Comment créer un compte VEGECE ?',
              answer: 'Téléchargez l\'application VEGECE depuis l\'App Store ou Google Play. Ouvrez l\'application et cliquez sur "Créer un compte". Renseignez votre email, créez un mot de passe sécurisé, et complétez votre profil. Vous recevrez un email de confirmation pour activer votre compte.'
            },
            {
              question: 'J\'ai oublié mon mot de passe, comment le réinitialiser ?',
              answer: 'Sur l\'écran de connexion, cliquez sur "Mot de passe oublié ?". Entrez l\'adresse email associée à votre compte. Vous recevrez un lien de réinitialisation par email. Suivez les instructions pour créer un nouveau mot de passe.'
            },
            {
              question: 'Comment modifier mes informations personnelles ?',
              answer: 'Connectez-vous à votre compte, accédez à la section "Profil" ou "Paramètres". Vous pouvez y modifier votre nom, email, numéro de téléphone et photo de profil. N\'oubliez pas de sauvegarder vos modifications.'
            },
            {
              question: 'Comment supprimer mon compte ?',
              answer: 'Pour supprimer votre compte, contactez-nous à privacy@vegece.com avec votre demande. Conformément à la réglementation, nous traiterons votre demande sous 30 jours. Notez que la suppression est irréversible et entraîne la perte de toutes vos données.'
            }
          ]
        },
        {
          title: 'Mes Animaux',
          icon: 'fa-paw',
          items: [
            {
              question: 'Comment ajouter un animal à mon compte ?',
              answer: 'Depuis l\'écran d\'accueil, cliquez sur "Ajouter un animal" ou le bouton "+". Renseignez les informations de votre animal : nom, espèce, race, date de naissance, sexe. Vous pouvez aussi ajouter une photo et le numéro de puce électronique si votre animal en possède une.'
            },
            {
              question: 'Comment accéder au carnet de santé de mon animal ?',
              answer: 'Sélectionnez votre animal depuis l\'écran d\'accueil. Accédez à la section "Carnet de santé" ou "Santé". Vous y trouverez l\'historique des vaccinations, les ordonnances, les consultations passées et les rappels à venir.'
            },
            {
              question: 'Puis-je partager le profil de mon animal avec mon vétérinaire ?',
              answer: 'Oui ! Vous pouvez générer un code QR unique pour votre animal. Le vétérinaire peut scanner ce code pour accéder aux informations médicales de votre animal. Vous contrôlez quelles informations sont partagées.'
            },
            {
              question: 'Comment sont protégées les données de mon animal ?',
              answer: 'Toutes les données sont chiffrées et stockées de manière sécurisée. Seuls vous et les professionnels autorisés peuvent accéder aux informations de votre animal. Consultez notre Politique de Confidentialité pour plus de détails.'
            }
          ]
        },
        {
          title: 'Réservations',
          icon: 'fa-calendar-check',
          items: [
            {
              question: 'Comment réserver un rendez-vous vétérinaire ?',
              answer: 'Utilisez la fonction "Rechercher" pour trouver des vétérinaires près de chez vous. Sélectionnez un professionnel et consultez ses disponibilités. Choisissez un créneau, sélectionnez l\'animal concerné et confirmez la réservation. Vous recevrez une confirmation par notification et email.'
            },
            {
              question: 'Comment annuler ou modifier un rendez-vous ?',
              answer: 'Accédez à la section "Mes rendez-vous" dans l\'application. Sélectionnez le rendez-vous concerné et cliquez sur "Modifier" ou "Annuler". Note : les annulations doivent être effectuées au moins 24h à l\'avance pour éviter des frais.'
            },
            {
              question: 'Comment fonctionne le système de confirmation ?',
              answer: 'Après votre réservation, le professionnel reçoit une notification. Il peut confirmer ou proposer un autre créneau. Une fois confirmé, vous recevez un code OTP à présenter lors de votre visite pour valider le rendez-vous.'
            },
            {
              question: 'Que faire si le vétérinaire annule mon rendez-vous ?',
              answer: 'Vous serez immédiatement notifié de l\'annulation. L\'application vous proposera automatiquement d\'autres créneaux disponibles chez le même professionnel ou des alternatives à proximité.'
            }
          ]
        },
        {
          title: 'Garderie',
          icon: 'fa-house',
          items: [
            {
              question: 'Comment réserver une garderie pour mon animal ?',
              answer: 'Recherchez des garderies dans votre zone via l\'onglet "Garderie". Consultez les profils, avis et tarifs des différentes garderies. Sélectionnez les dates souhaitées et effectuez votre réservation. N\'oubliez pas de renseigner les besoins spécifiques de votre animal.'
            },
            {
              question: 'Comment fonctionne le suivi pendant la garde ?',
              answer: 'Pendant la garde, vous pouvez recevoir des mises à jour et photos de votre animal via l\'application. L\'heure de dépôt et de récupération est enregistrée. En cas de retard à la récupération, des frais supplémentaires peuvent s\'appliquer.'
            },
            {
              question: 'Que se passe-t-il en cas de problème de santé pendant la garde ?',
              answer: 'En cas d\'urgence, la garderie vous contactera immédiatement. Avec votre accord, votre animal peut être emmené chez un vétérinaire partenaire. Les frais vétérinaires seront à votre charge sauf accord préalable différent.'
            }
          ]
        },
        {
          title: 'Adoption',
          icon: 'fa-heart',
          items: [
            {
              question: 'Comment publier une annonce d\'adoption ?',
              answer: 'Accédez à la section "Adoption" et cliquez sur "Publier une annonce". Renseignez les informations de l\'animal (photos, description, caractère, besoins). Votre annonce sera vérifiée par notre équipe avant publication (sous 24-48h).'
            },
            {
              question: 'Comment contacter un propriétaire pour une adoption ?',
              answer: 'Depuis une annonce d\'adoption, cliquez sur "Contacter". Vous pouvez envoyer un message au propriétaire via notre messagerie sécurisée. Vos coordonnées personnelles ne sont partagées qu\'avec votre consentement.'
            },
            {
              question: 'Comment sont vérifiées les annonces d\'adoption ?',
              answer: 'Chaque annonce est examinée par notre équipe modération pour vérifier sa conformité. Nous vérifions les photos, la description et nous nous assurons qu\'il ne s\'agit pas d\'une arnaque. Les annonces suspectes sont refusées.'
            }
          ]
        },
        {
          title: 'Paiements',
          icon: 'fa-credit-card',
          items: [
            {
              question: 'Quels modes de paiement sont acceptés ?',
              answer: 'Le paiement des services se fait généralement directement auprès du professionnel (espèces, carte bancaire selon les établissements). Certains professionnels peuvent proposer le paiement en ligne via l\'application.'
            },
            {
              question: 'L\'application VEGECE est-elle payante ?',
              answer: 'L\'inscription et l\'utilisation des fonctionnalités de base de VEGECE sont gratuites pour les propriétaires d\'animaux. Seuls les services des professionnels (consultations, garderies, etc.) sont payants selon leurs propres tarifs.'
            },
            {
              question: 'Comment obtenir une facture ?',
              answer: 'Les factures sont émises par les professionnels directement. Vous pouvez également accéder à l\'historique de vos réservations dans l\'application pour consulter les détails des paiements effectués.'
            }
          ]
        }
      ] as FAQCategory[]
    },
    en: {
      title: 'Help Center',
      subtitle: 'Quickly find answers to your questions',
      searchPlaceholder: 'Search for a question...',
      contactTitle: 'Need more help?',
      contactSubtitle: 'Our team is here to assist you',
      contactCards: [
        {
          icon: 'fa-envelope',
          title: 'Email',
          desc: 'Response within 24h',
          link: 'mailto:support@vegece.com',
          linkText: 'support@vegece.com'
        },
        {
          icon: 'fa-phone',
          title: 'Phone',
          desc: 'Mon-Fri, 9am-6pm',
          link: 'tel:+213XXXXXXXX',
          linkText: '+213 XX XX XX XX'
        },
        {
          icon: 'fa-comments',
          title: 'Live Chat',
          desc: 'Available in the app',
          link: '#',
          linkText: 'Open chat'
        }
      ],
      faq: [
        {
          title: 'Account & Registration',
          icon: 'fa-user-circle',
          items: [
            {
              question: 'How do I create a VEGECE account?',
              answer: 'Download the VEGECE app from the App Store or Google Play. Open the app and click "Create an account". Enter your email, create a secure password, and complete your profile. You will receive a confirmation email to activate your account.'
            },
            {
              question: 'I forgot my password, how do I reset it?',
              answer: 'On the login screen, click "Forgot password?". Enter the email address associated with your account. You will receive a reset link by email. Follow the instructions to create a new password.'
            },
            {
              question: 'How do I edit my personal information?',
              answer: 'Log in to your account and go to the "Profile" or "Settings" section. You can edit your name, email, phone number, and profile photo. Don\'t forget to save your changes.'
            },
            {
              question: 'How do I delete my account?',
              answer: 'To delete your account, contact us at privacy@vegece.com with your request. In accordance with regulations, we will process your request within 30 days. Note that deletion is irreversible and results in the loss of all your data.'
            }
          ]
        },
        {
          title: 'My Pets',
          icon: 'fa-paw',
          items: [
            {
              question: 'How do I add a pet to my account?',
              answer: 'From the home screen, click "Add a pet" or the "+" button. Enter your pet\'s information: name, species, breed, date of birth, gender. You can also add a photo and microchip number if your pet has one.'
            },
            {
              question: 'How do I access my pet\'s health record?',
              answer: 'Select your pet from the home screen. Go to the "Health record" or "Health" section. You will find vaccination history, prescriptions, past consultations, and upcoming reminders.'
            },
            {
              question: 'Can I share my pet\'s profile with my veterinarian?',
              answer: 'Yes! You can generate a unique QR code for your pet. The veterinarian can scan this code to access your pet\'s medical information. You control which information is shared.'
            },
            {
              question: 'How is my pet\'s data protected?',
              answer: 'All data is encrypted and stored securely. Only you and authorized professionals can access your pet\'s information. See our Privacy Policy for more details.'
            }
          ]
        },
        {
          title: 'Bookings',
          icon: 'fa-calendar-check',
          items: [
            {
              question: 'How do I book a veterinary appointment?',
              answer: 'Use the "Search" function to find veterinarians near you. Select a professional and view their availability. Choose a time slot, select the pet concerned, and confirm the booking. You will receive confirmation by notification and email.'
            },
            {
              question: 'How do I cancel or modify an appointment?',
              answer: 'Go to the "My appointments" section in the app. Select the appointment and click "Modify" or "Cancel". Note: cancellations must be made at least 24 hours in advance to avoid fees.'
            },
            {
              question: 'How does the confirmation system work?',
              answer: 'After your booking, the professional receives a notification. They can confirm or propose another time slot. Once confirmed, you receive an OTP code to present during your visit to validate the appointment.'
            },
            {
              question: 'What if the veterinarian cancels my appointment?',
              answer: 'You will be immediately notified of the cancellation. The app will automatically suggest other available slots with the same professional or nearby alternatives.'
            }
          ]
        },
        {
          title: 'Daycare',
          icon: 'fa-house',
          items: [
            {
              question: 'How do I book daycare for my pet?',
              answer: 'Search for daycares in your area via the "Daycare" tab. View profiles, reviews, and rates of different daycares. Select your desired dates and make your booking. Don\'t forget to specify your pet\'s special needs.'
            },
            {
              question: 'How does tracking work during care?',
              answer: 'During care, you can receive updates and photos of your pet through the app. Drop-off and pick-up times are recorded. In case of late pick-up, additional fees may apply.'
            },
            {
              question: 'What happens if there\'s a health issue during care?',
              answer: 'In case of emergency, the daycare will contact you immediately. With your consent, your pet can be taken to a partner veterinarian. Veterinary fees will be your responsibility unless otherwise agreed.'
            }
          ]
        },
        {
          title: 'Adoption',
          icon: 'fa-heart',
          items: [
            {
              question: 'How do I post an adoption listing?',
              answer: 'Go to the "Adoption" section and click "Post a listing". Enter the animal\'s information (photos, description, personality, needs). Your listing will be reviewed by our team before publication (within 24-48h).'
            },
            {
              question: 'How do I contact an owner for adoption?',
              answer: 'From an adoption listing, click "Contact". You can send a message to the owner via our secure messaging. Your personal contact information is only shared with your consent.'
            },
            {
              question: 'How are adoption listings verified?',
              answer: 'Each listing is reviewed by our moderation team to verify compliance. We check photos, descriptions, and ensure it\'s not a scam. Suspicious listings are rejected.'
            }
          ]
        },
        {
          title: 'Payments',
          icon: 'fa-credit-card',
          items: [
            {
              question: 'What payment methods are accepted?',
              answer: 'Payment for services is generally made directly to the professional (cash, credit card depending on the establishment). Some professionals may offer online payment through the app.'
            },
            {
              question: 'Is the VEGECE app paid?',
              answer: 'Registration and use of basic VEGECE features are free for pet owners. Only professional services (consultations, daycares, etc.) are paid according to their own rates.'
            },
            {
              question: 'How do I get an invoice?',
              answer: 'Invoices are issued directly by professionals. You can also access your booking history in the app to view payment details.'
            }
          ]
        }
      ] as FAQCategory[]
    },
    ar: {
      title: 'مركز المساعدة',
      subtitle: 'ابحث بسرعة عن إجابات لأسئلتك',
      searchPlaceholder: 'ابحث عن سؤال...',
      contactTitle: 'تحتاج مزيدًا من المساعدة؟',
      contactSubtitle: 'فريقنا هنا لمساعدتك',
      contactCards: [
        {
          icon: 'fa-envelope',
          title: 'البريد الإلكتروني',
          desc: 'الرد خلال 24 ساعة',
          link: 'mailto:support@vegece.com',
          linkText: 'support@vegece.com'
        },
        {
          icon: 'fa-phone',
          title: 'الهاتف',
          desc: 'الاثنين-الجمعة، 9ص-6م',
          link: 'tel:+213XXXXXXXX',
          linkText: '+213 XX XX XX XX'
        },
        {
          icon: 'fa-comments',
          title: 'الدردشة المباشرة',
          desc: 'متوفرة في التطبيق',
          link: '#',
          linkText: 'فتح الدردشة'
        }
      ],
      faq: [
        {
          title: 'الحساب والتسجيل',
          icon: 'fa-user-circle',
          items: [
            {
              question: 'كيف أنشئ حساب VEGECE؟',
              answer: 'قم بتحميل تطبيق VEGECE من App Store أو Google Play. افتح التطبيق وانقر على "إنشاء حساب". أدخل بريدك الإلكتروني، وأنشئ كلمة مرور آمنة، وأكمل ملفك الشخصي. ستتلقى بريدًا إلكترونيًا للتأكيد لتفعيل حسابك.'
            },
            {
              question: 'نسيت كلمة المرور، كيف أعيد تعيينها؟',
              answer: 'في شاشة تسجيل الدخول، انقر على "نسيت كلمة المرور؟". أدخل عنوان البريد الإلكتروني المرتبط بحسابك. ستتلقى رابط إعادة التعيين عبر البريد الإلكتروني. اتبع التعليمات لإنشاء كلمة مرور جديدة.'
            },
            {
              question: 'كيف أعدل معلوماتي الشخصية؟',
              answer: 'سجل الدخول إلى حسابك واذهب إلى قسم "الملف الشخصي" أو "الإعدادات". يمكنك تعديل اسمك وبريدك الإلكتروني ورقم هاتفك وصورة ملفك الشخصي. لا تنس حفظ التغييرات.'
            },
            {
              question: 'كيف أحذف حسابي؟',
              answer: 'لحذف حسابك، تواصل معنا على privacy@vegece.com مع طلبك. وفقًا للوائح، سنعالج طلبك خلال 30 يومًا. لاحظ أن الحذف لا رجعة فيه ويؤدي إلى فقدان جميع بياناتك.'
            }
          ]
        },
        {
          title: 'حيواناتي',
          icon: 'fa-paw',
          items: [
            {
              question: 'كيف أضيف حيوانًا إلى حسابي؟',
              answer: 'من الشاشة الرئيسية، انقر على "إضافة حيوان" أو زر "+". أدخل معلومات حيوانك: الاسم، النوع، السلالة، تاريخ الميلاد، الجنس. يمكنك أيضًا إضافة صورة ورقم الشريحة الإلكترونية إذا كان لحيوانك واحدة.'
            },
            {
              question: 'كيف أصل إلى السجل الصحي لحيواني؟',
              answer: 'اختر حيوانك من الشاشة الرئيسية. اذهب إلى قسم "السجل الصحي" أو "الصحة". ستجد تاريخ التطعيمات والوصفات والاستشارات السابقة والتذكيرات القادمة.'
            },
            {
              question: 'هل يمكنني مشاركة ملف حيواني مع طبيبي البيطري؟',
              answer: 'نعم! يمكنك إنشاء رمز QR فريد لحيوانك. يمكن للطبيب البيطري مسح هذا الرمز للوصول إلى المعلومات الطبية لحيوانك. أنت تتحكم في المعلومات التي تتم مشاركتها.'
            }
          ]
        },
        {
          title: 'الحجوزات',
          icon: 'fa-calendar-check',
          items: [
            {
              question: 'كيف أحجز موعدًا بيطريًا؟',
              answer: 'استخدم وظيفة "البحث" للعثور على أطباء بيطريين قريبين منك. اختر محترفًا واطلع على توفره. اختر موعدًا، وحدد الحيوان المعني، وأكد الحجز. ستتلقى تأكيدًا عبر الإشعار والبريد الإلكتروني.'
            },
            {
              question: 'كيف ألغي أو أعدل موعدًا؟',
              answer: 'اذهب إلى قسم "مواعيدي" في التطبيق. اختر الموعد وانقر على "تعديل" أو "إلغاء". ملاحظة: يجب إجراء الإلغاءات قبل 24 ساعة على الأقل لتجنب الرسوم.'
            }
          ]
        },
        {
          title: 'الحضانة',
          icon: 'fa-house',
          items: [
            {
              question: 'كيف أحجز حضانة لحيواني؟',
              answer: 'ابحث عن حضانات في منطقتك عبر علامة تبويب "الحضانة". اطلع على الملفات الشخصية والتقييمات والأسعار للحضانات المختلفة. حدد التواريخ المطلوبة وقم بحجزك. لا تنس تحديد الاحتياجات الخاصة لحيوانك.'
            },
            {
              question: 'كيف يعمل التتبع أثناء الرعاية؟',
              answer: 'أثناء الرعاية، يمكنك تلقي تحديثات وصور لحيوانك عبر التطبيق. يتم تسجيل أوقات التسليم والاستلام. في حالة التأخر في الاستلام، قد تطبق رسوم إضافية.'
            }
          ]
        },
        {
          title: 'التبني',
          icon: 'fa-heart',
          items: [
            {
              question: 'كيف أنشر إعلان تبني؟',
              answer: 'اذهب إلى قسم "التبني" وانقر على "نشر إعلان". أدخل معلومات الحيوان (الصور، الوصف، الشخصية، الاحتياجات). سيتم مراجعة إعلانك من قبل فريقنا قبل النشر (خلال 24-48 ساعة).'
            },
            {
              question: 'كيف أتواصل مع مالك للتبني؟',
              answer: 'من إعلان التبني، انقر على "تواصل". يمكنك إرسال رسالة للمالك عبر نظام المراسلة الآمن الخاص بنا. تتم مشاركة معلومات الاتصال الشخصية فقط بموافقتك.'
            }
          ]
        },
        {
          title: 'المدفوعات',
          icon: 'fa-credit-card',
          items: [
            {
              question: 'ما طرق الدفع المقبولة؟',
              answer: 'يتم دفع الخدمات عادة مباشرة للمحترف (نقدًا، بطاقة ائتمان حسب المؤسسة). قد يقدم بعض المحترفين الدفع عبر الإنترنت من خلال التطبيق.'
            },
            {
              question: 'هل تطبيق VEGECE مدفوع؟',
              answer: 'التسجيل واستخدام الميزات الأساسية لـ VEGECE مجاني لأصحاب الحيوانات الأليفة. فقط خدمات المحترفين (الاستشارات، الحضانات، إلخ) مدفوعة وفقًا لأسعارهم الخاصة.'
            }
          ]
        }
      ] as FAQCategory[]
    }
  };

  const t = content[language];

  // Filter FAQ based on search query
  const filteredFaq = t.faq.map(category => ({
    ...category,
    items: category.items.filter(item =>
      searchQuery === '' ||
      item.question.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.answer.toLowerCase().includes(searchQuery.toLowerCase())
    )
  })).filter(category => category.items.length > 0);

  return (
    <LegalLayout title={t.title} subtitle={t.subtitle}>
      {/* Search */}
      <div className="support-hero">
        <div className="support-search">
          <i className="fa-solid fa-magnifying-glass"></i>
          <input
            type="text"
            placeholder={t.searchPlaceholder}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>

      {/* FAQ */}
      {filteredFaq.map((category, catIndex) => (
        <div key={catIndex} className="faq-category">
          <h2 className="faq-category-title">
            <i className={`fa-solid ${category.icon}`}></i>
            {category.title}
          </h2>
          {category.items.map((item, itemIndex) => {
            const itemId = `${catIndex}-${itemIndex}`;
            const isActive = activeItems.has(itemId);
            return (
              <div key={itemIndex} className={`faq-item ${isActive ? 'active' : ''}`}>
                <button className="faq-question" onClick={() => toggleItem(itemId)}>
                  {item.question}
                  <i className="fa-solid fa-chevron-down"></i>
                </button>
                <div className="faq-answer">
                  <p>{item.answer}</p>
                </div>
              </div>
            );
          })}
        </div>
      ))}

      {/* Contact Section */}
      <section className="legal-section">
        <h2 className="legal-section-title">
          <i className="fa-solid fa-headset"></i>
          {t.contactTitle}
        </h2>
        <p className="legal-section-content">{t.contactSubtitle}</p>

        <div className="contact-grid">
          {t.contactCards.map((card, index) => (
            <div key={index} className="contact-card">
              <div className="contact-card-icon">
                <i className={`fa-solid ${card.icon}`}></i>
              </div>
              <h3 className="contact-card-title">{card.title}</h3>
              <p className="contact-card-desc">{card.desc}</p>
              <a href={card.link} className="contact-card-link">
                {card.linkText}
                <i className="fa-solid fa-arrow-right"></i>
              </a>
            </div>
          ))}
        </div>
      </section>
    </LegalLayout>
  );
}

export default SupportPage;
