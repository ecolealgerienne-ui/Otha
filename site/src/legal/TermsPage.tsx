import { useEffect } from 'react';
import { LegalLayout } from './LegalLayout';
import { useLanguage } from '../i18n';

export function TermsPage() {
  const { language } = useLanguage();

  useEffect(() => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
    document.head.appendChild(link);
    return () => {
      document.head.removeChild(link);
    };
  }, []);

  const content = {
    fr: {
      title: 'Conditions Générales d\'Utilisation',
      subtitle: 'Règles et conditions d\'utilisation de l\'application VEGECE',
      lastUpdate: 'Dernière mise à jour : Décembre 2025',
      sections: {
        object: {
          title: 'Objet et acceptation',
          content: `
            <p>Les présentes Conditions Générales d'Utilisation (ci-après "CGU") ont pour objet de définir les conditions d'accès et d'utilisation de l'application mobile et du site web VEGECE (ci-après "l'Application").</p>
            <p>L'Application VEGECE est une plateforme de mise en relation entre :</p>
            <ul>
              <li>Les propriétaires d'animaux de compagnie (ci-après "Utilisateurs")</li>
              <li>Les professionnels vétérinaires et prestataires de services animaliers (ci-après "Professionnels")</li>
            </ul>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-check-circle"></i> Acceptation des CGU</div>
              <div class="legal-info-card-content">
                <p>L'utilisation de l'Application implique l'acceptation pleine et entière des présentes CGU. Si vous n'acceptez pas ces conditions, veuillez ne pas utiliser l'Application.</p>
              </div>
            </div>
          `
        },
        services: {
          title: 'Description des services',
          content: `
            <p>VEGECE propose les services suivants :</p>
            <ul>
              <li><strong>Carnet de santé numérique :</strong> suivi des vaccinations, traitements, ordonnances et historique médical de vos animaux</li>
              <li><strong>Réservation de rendez-vous :</strong> prise de rendez-vous en ligne auprès de vétérinaires partenaires</li>
              <li><strong>Géolocalisation :</strong> recherche de vétérinaires, garderies et pet shops à proximité</li>
              <li><strong>Garderie :</strong> réservation de services de garde pour animaux</li>
              <li><strong>Adoption :</strong> plateforme de mise en relation pour l'adoption d'animaux</li>
              <li><strong>Rappels :</strong> notifications automatiques pour les vaccins et rendez-vous</li>
            </ul>
          `
        },
        registration: {
          title: 'Inscription et compte utilisateur',
          content: `
            <p><strong>Conditions d'inscription :</strong></p>
            <ul>
              <li>Être âgé d'au moins 18 ans ou avoir l'autorisation d'un représentant légal</li>
              <li>Fournir des informations exactes et à jour</li>
              <li>Disposer d'une adresse email valide</li>
              <li>Accepter les présentes CGU et la Politique de Confidentialité</li>
            </ul>
            <p><strong>Responsabilité du compte :</strong></p>
            <ul>
              <li>Vous êtes responsable de la confidentialité de vos identifiants de connexion</li>
              <li>Toute activité réalisée depuis votre compte est sous votre responsabilité</li>
              <li>Vous devez nous informer immédiatement de toute utilisation non autorisée de votre compte</li>
            </ul>
          `
        },
        userObligations: {
          title: 'Obligations des utilisateurs',
          content: `
            <p>En utilisant l'Application, vous vous engagez à :</p>
            <ul>
              <li>Utiliser l'Application conformément à sa destination et aux lois en vigueur</li>
              <li>Fournir des informations exactes concernant vos animaux</li>
              <li>Respecter les rendez-vous pris avec les Professionnels</li>
              <li>Ne pas publier de contenu illégal, diffamatoire, obscène ou offensant</li>
              <li>Ne pas usurper l'identité d'une autre personne</li>
              <li>Ne pas tenter de nuire au fonctionnement de l'Application</li>
              <li>Respecter les droits de propriété intellectuelle</li>
            </ul>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-ban"></i> Comportements interdits</div>
              <div class="legal-info-card-content">
                <p>Sont strictement interdits : le harcèlement, les fausses déclarations, la fraude, l'envoi de spam, la collecte de données d'autres utilisateurs, et toute tentative de contournement des mesures de sécurité.</p>
              </div>
            </div>
          `
        },
        proObligations: {
          title: 'Obligations des professionnels',
          content: `
            <p>Les Professionnels utilisant l'Application s'engagent à :</p>
            <ul>
              <li>Détenir les qualifications et autorisations nécessaires à l'exercice de leur activité</li>
              <li>Fournir des informations exactes sur leurs services et tarifs</li>
              <li>Honorer les rendez-vous pris via l'Application</li>
              <li>Respecter la confidentialité des informations des Utilisateurs et de leurs animaux</li>
              <li>Se conformer aux règles déontologiques de leur profession</li>
              <li>Maintenir leurs disponibilités à jour sur l'Application</li>
            </ul>
          `
        },
        payments: {
          title: 'Tarification et paiements',
          content: `
            <p><strong>Pour les Utilisateurs :</strong></p>
            <ul>
              <li>L'inscription et l'utilisation des fonctionnalités de base sont gratuites</li>
              <li>Les services des Professionnels sont facturés selon leurs propres tarifs</li>
              <li>Le paiement s'effectue directement auprès du Professionnel ou via l'Application</li>
            </ul>
            <p><strong>Pour les Professionnels :</strong></p>
            <ul>
              <li>Une commission de <strong>100 DA</strong> est prélevée sur chaque réservation effectuée via l'Application</li>
              <li>Les revenus sont versés mensuellement selon les modalités convenues</li>
            </ul>
            <p><strong>Politique d'annulation :</strong></p>
            <ul>
              <li>Les annulations doivent être effectuées au moins 24 heures avant le rendez-vous</li>
              <li>En cas d'annulation tardive ou de non-présentation, des frais peuvent s'appliquer</li>
            </ul>
          `
        },
        responsibility: {
          title: 'Responsabilité de VEGECE',
          content: `
            <p>VEGECE agit en qualité d'<strong>intermédiaire technique</strong> entre les Utilisateurs et les Professionnels.</p>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-exclamation-triangle"></i> Limitation de responsabilité</div>
              <div class="legal-info-card-content">
                <p>VEGECE n'est pas responsable :</p>
                <ul>
                  <li>Des actes, conseils ou traitements prodigués par les Professionnels</li>
                  <li>De la qualité des services rendus par les Professionnels</li>
                  <li>Des litiges entre Utilisateurs et Professionnels</li>
                  <li>Des dommages causés aux animaux lors des consultations ou garderies</li>
                  <li>Des interruptions temporaires du service pour maintenance</li>
                </ul>
              </div>
            </div>
            <p>VEGECE s'engage toutefois à :</p>
            <ul>
              <li>Vérifier les qualifications des Professionnels avant leur inscription</li>
              <li>Assurer la sécurité et la disponibilité de l'Application</li>
              <li>Traiter les réclamations des Utilisateurs dans les meilleurs délais</li>
            </ul>
          `
        },
        intellectual: {
          title: 'Propriété intellectuelle',
          content: `
            <p>L'ensemble des éléments de l'Application (marque, logo, design, code, contenus) sont la propriété exclusive de VEGECE SAS.</p>
            <p><strong>Licence d'utilisation :</strong></p>
            <ul>
              <li>VEGECE vous accorde une licence personnelle, non-exclusive et non-transférable d'utilisation de l'Application</li>
              <li>Cette licence est limitée à un usage strictement personnel et non commercial</li>
            </ul>
            <p><strong>Contenus utilisateur :</strong></p>
            <ul>
              <li>Vous conservez la propriété des contenus que vous publiez (photos, commentaires)</li>
              <li>Vous accordez à VEGECE une licence d'utilisation de ces contenus pour le fonctionnement de l'Application</li>
            </ul>
          `
        },
        suspension: {
          title: 'Suspension et résiliation',
          content: `
            <p>VEGECE se réserve le droit de suspendre ou résilier votre compte en cas de :</p>
            <ul>
              <li>Non-respect des présentes CGU</li>
              <li>Comportement frauduleux ou abusif</li>
              <li>Publication de contenus illicites</li>
              <li>Non-paiement des sommes dues (pour les Professionnels)</li>
              <li>Inactivité prolongée du compte (plus de 24 mois)</li>
            </ul>
            <p><strong>Conséquences de la résiliation :</strong></p>
            <ul>
              <li>Vous perdez l'accès à votre compte et à vos données</li>
              <li>Les réservations en cours peuvent être annulées</li>
              <li>Vous pouvez demander l'export de vos données avant la clôture</li>
            </ul>
          `
        },
        modifications: {
          title: 'Modifications des CGU',
          content: `
            <p>VEGECE se réserve le droit de modifier les présentes CGU à tout moment.</p>
            <p>En cas de modification substantielle :</p>
            <ul>
              <li>Vous serez informé par email ou notification dans l'Application</li>
              <li>Un délai de 30 jours vous sera accordé pour prendre connaissance des modifications</li>
              <li>La poursuite de l'utilisation de l'Application vaut acceptation des nouvelles CGU</li>
            </ul>
          `
        },
        law: {
          title: 'Droit applicable et litiges',
          content: `
            <p>Les présentes CGU sont régies par le <strong>droit algérien</strong>.</p>
            <p>En cas de litige :</p>
            <ol>
              <li><strong>Médiation :</strong> Nous vous encourageons à nous contacter d'abord pour tenter de résoudre le différend à l'amiable</li>
              <li><strong>Juridiction :</strong> À défaut de résolution amiable, les tribunaux algériens seront seuls compétents</li>
            </ol>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-envelope"></i> Contact</div>
              <div class="legal-info-card-content">
                <p>Pour toute question concernant ces CGU : <a href="mailto:legal@vegece.com">legal@vegece.com</a></p>
              </div>
            </div>
          `
        }
      }
    },
    en: {
      title: 'Terms of Use',
      subtitle: 'Rules and conditions for using the VEGECE application',
      lastUpdate: 'Last updated: December 2025',
      sections: {
        object: {
          title: 'Purpose and Acceptance',
          content: `
            <p>These Terms of Use (hereinafter "Terms") define the conditions for accessing and using the VEGECE mobile application and website (hereinafter "the Application").</p>
            <p>The VEGECE Application is a platform connecting:</p>
            <ul>
              <li>Pet owners (hereinafter "Users")</li>
              <li>Veterinary professionals and animal service providers (hereinafter "Professionals")</li>
            </ul>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-check-circle"></i> Acceptance of Terms</div>
              <div class="legal-info-card-content">
                <p>Using the Application implies full and complete acceptance of these Terms. If you do not accept these conditions, please do not use the Application.</p>
              </div>
            </div>
          `
        },
        services: {
          title: 'Description of Services',
          content: `
            <p>VEGECE offers the following services:</p>
            <ul>
              <li><strong>Digital health record:</strong> tracking vaccinations, treatments, prescriptions, and medical history of your pets</li>
              <li><strong>Appointment booking:</strong> online appointment scheduling with partner veterinarians</li>
              <li><strong>Geolocation:</strong> search for nearby veterinarians, daycares, and pet shops</li>
              <li><strong>Daycare:</strong> booking pet care services</li>
              <li><strong>Adoption:</strong> platform for pet adoption connections</li>
              <li><strong>Reminders:</strong> automatic notifications for vaccines and appointments</li>
            </ul>
          `
        },
        registration: {
          title: 'Registration and User Account',
          content: `
            <p><strong>Registration requirements:</strong></p>
            <ul>
              <li>Be at least 18 years old or have authorization from a legal guardian</li>
              <li>Provide accurate and up-to-date information</li>
              <li>Have a valid email address</li>
              <li>Accept these Terms and the Privacy Policy</li>
            </ul>
            <p><strong>Account responsibility:</strong></p>
            <ul>
              <li>You are responsible for the confidentiality of your login credentials</li>
              <li>Any activity performed from your account is your responsibility</li>
              <li>You must immediately inform us of any unauthorized use of your account</li>
            </ul>
          `
        },
        userObligations: {
          title: 'User Obligations',
          content: `
            <p>By using the Application, you agree to:</p>
            <ul>
              <li>Use the Application in accordance with its purpose and applicable laws</li>
              <li>Provide accurate information about your pets</li>
              <li>Respect appointments made with Professionals</li>
              <li>Not publish illegal, defamatory, obscene, or offensive content</li>
              <li>Not impersonate another person</li>
              <li>Not attempt to harm the operation of the Application</li>
              <li>Respect intellectual property rights</li>
            </ul>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-ban"></i> Prohibited Behavior</div>
              <div class="legal-info-card-content">
                <p>Strictly prohibited: harassment, false statements, fraud, spamming, collecting other users' data, and any attempt to circumvent security measures.</p>
              </div>
            </div>
          `
        },
        proObligations: {
          title: 'Professional Obligations',
          content: `
            <p>Professionals using the Application agree to:</p>
            <ul>
              <li>Hold the qualifications and authorizations necessary for their activity</li>
              <li>Provide accurate information about their services and rates</li>
              <li>Honor appointments made through the Application</li>
              <li>Respect the confidentiality of Users' and their pets' information</li>
              <li>Comply with the ethical rules of their profession</li>
              <li>Keep their availability up to date on the Application</li>
            </ul>
          `
        },
        payments: {
          title: 'Pricing and Payments',
          content: `
            <p><strong>For Users:</strong></p>
            <ul>
              <li>Registration and use of basic features are free</li>
              <li>Professional services are billed according to their own rates</li>
              <li>Payment is made directly to the Professional or through the Application</li>
            </ul>
            <p><strong>For Professionals:</strong></p>
            <ul>
              <li>A commission of <strong>100 DA</strong> is charged on each booking made through the Application</li>
              <li>Earnings are paid monthly according to agreed terms</li>
            </ul>
            <p><strong>Cancellation policy:</strong></p>
            <ul>
              <li>Cancellations must be made at least 24 hours before the appointment</li>
              <li>Late cancellation or no-show fees may apply</li>
            </ul>
          `
        },
        responsibility: {
          title: 'VEGECE Liability',
          content: `
            <p>VEGECE acts as a <strong>technical intermediary</strong> between Users and Professionals.</p>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-exclamation-triangle"></i> Limitation of Liability</div>
              <div class="legal-info-card-content">
                <p>VEGECE is not responsible for:</p>
                <ul>
                  <li>Acts, advice, or treatments provided by Professionals</li>
                  <li>The quality of services rendered by Professionals</li>
                  <li>Disputes between Users and Professionals</li>
                  <li>Damage caused to pets during consultations or daycare</li>
                  <li>Temporary service interruptions for maintenance</li>
                </ul>
              </div>
            </div>
            <p>However, VEGECE commits to:</p>
            <ul>
              <li>Verify Professionals' qualifications before registration</li>
              <li>Ensure the security and availability of the Application</li>
              <li>Process User complaints promptly</li>
            </ul>
          `
        },
        intellectual: {
          title: 'Intellectual Property',
          content: `
            <p>All elements of the Application (brand, logo, design, code, content) are the exclusive property of VEGECE SAS.</p>
            <p><strong>License of use:</strong></p>
            <ul>
              <li>VEGECE grants you a personal, non-exclusive, and non-transferable license to use the Application</li>
              <li>This license is limited to strictly personal and non-commercial use</li>
            </ul>
            <p><strong>User content:</strong></p>
            <ul>
              <li>You retain ownership of the content you publish (photos, comments)</li>
              <li>You grant VEGECE a license to use this content for the operation of the Application</li>
            </ul>
          `
        },
        suspension: {
          title: 'Suspension and Termination',
          content: `
            <p>VEGECE reserves the right to suspend or terminate your account in case of:</p>
            <ul>
              <li>Non-compliance with these Terms</li>
              <li>Fraudulent or abusive behavior</li>
              <li>Publication of illegal content</li>
              <li>Non-payment of amounts due (for Professionals)</li>
              <li>Prolonged account inactivity (more than 24 months)</li>
            </ul>
            <p><strong>Consequences of termination:</strong></p>
            <ul>
              <li>You lose access to your account and data</li>
              <li>Pending bookings may be canceled</li>
              <li>You can request export of your data before closure</li>
            </ul>
          `
        },
        modifications: {
          title: 'Modifications to Terms',
          content: `
            <p>VEGECE reserves the right to modify these Terms at any time.</p>
            <p>In case of substantial modification:</p>
            <ul>
              <li>You will be informed by email or notification in the Application</li>
              <li>A 30-day period will be granted to review the modifications</li>
              <li>Continued use of the Application constitutes acceptance of the new Terms</li>
            </ul>
          `
        },
        law: {
          title: 'Applicable Law and Disputes',
          content: `
            <p>These Terms are governed by <strong>Algerian law</strong>.</p>
            <p>In case of dispute:</p>
            <ol>
              <li><strong>Mediation:</strong> We encourage you to contact us first to try to resolve the dispute amicably</li>
              <li><strong>Jurisdiction:</strong> Failing amicable resolution, Algerian courts will have sole jurisdiction</li>
            </ol>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-envelope"></i> Contact</div>
              <div class="legal-info-card-content">
                <p>For any questions about these Terms: <a href="mailto:legal@vegece.com">legal@vegece.com</a></p>
              </div>
            </div>
          `
        }
      }
    },
    ar: {
      title: 'شروط الاستخدام',
      subtitle: 'قواعد وشروط استخدام تطبيق VEGECE',
      lastUpdate: 'آخر تحديث: ديسمبر 2025',
      sections: {
        object: {
          title: 'الغرض والقبول',
          content: `
            <p>تحدد شروط الاستخدام هذه (المشار إليها فيما بعد بـ "الشروط") شروط الوصول واستخدام تطبيق VEGECE للهاتف المحمول والموقع الإلكتروني (المشار إليه فيما بعد بـ "التطبيق").</p>
            <p>تطبيق VEGECE هو منصة تربط بين:</p>
            <ul>
              <li>أصحاب الحيوانات الأليفة (المشار إليهم فيما بعد بـ "المستخدمين")</li>
              <li>المحترفين البيطريين ومقدمي خدمات الحيوانات (المشار إليهم فيما بعد بـ "المحترفين")</li>
            </ul>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-check-circle"></i> قبول الشروط</div>
              <div class="legal-info-card-content">
                <p>استخدام التطبيق يعني القبول الكامل لهذه الشروط. إذا لم تقبل هذه الشروط، يرجى عدم استخدام التطبيق.</p>
              </div>
            </div>
          `
        },
        services: {
          title: 'وصف الخدمات',
          content: `
            <p>تقدم VEGECE الخدمات التالية:</p>
            <ul>
              <li><strong>السجل الصحي الرقمي:</strong> تتبع التطعيمات والعلاجات والوصفات والتاريخ الطبي لحيواناتك</li>
              <li><strong>حجز المواعيد:</strong> جدولة المواعيد عبر الإنترنت مع الأطباء البيطريين الشركاء</li>
              <li><strong>تحديد الموقع:</strong> البحث عن الأطباء البيطريين والحضانات ومتاجر الحيوانات القريبة</li>
              <li><strong>الحضانة:</strong> حجز خدمات رعاية الحيوانات</li>
              <li><strong>التبني:</strong> منصة للتواصل لتبني الحيوانات</li>
              <li><strong>التذكيرات:</strong> إشعارات تلقائية للتطعيمات والمواعيد</li>
            </ul>
          `
        },
        registration: {
          title: 'التسجيل وحساب المستخدم',
          content: `
            <p><strong>متطلبات التسجيل:</strong></p>
            <ul>
              <li>أن تكون عمرك 18 عامًا على الأقل أو لديك إذن من ولي أمر قانوني</li>
              <li>تقديم معلومات دقيقة ومحدثة</li>
              <li>امتلاك عنوان بريد إلكتروني صالح</li>
              <li>قبول هذه الشروط وسياسة الخصوصية</li>
            </ul>
            <p><strong>مسؤولية الحساب:</strong></p>
            <ul>
              <li>أنت مسؤول عن سرية بيانات تسجيل الدخول الخاصة بك</li>
              <li>أي نشاط يتم من حسابك هو مسؤوليتك</li>
              <li>يجب إبلاغنا فورًا بأي استخدام غير مصرح به لحسابك</li>
            </ul>
          `
        },
        userObligations: {
          title: 'التزامات المستخدمين',
          content: `
            <p>باستخدام التطبيق، توافق على:</p>
            <ul>
              <li>استخدام التطبيق وفقًا لغرضه والقوانين المعمول بها</li>
              <li>تقديم معلومات دقيقة عن حيواناتك</li>
              <li>احترام المواعيد المحجوزة مع المحترفين</li>
              <li>عدم نشر محتوى غير قانوني أو مسيء</li>
              <li>عدم انتحال شخصية شخص آخر</li>
              <li>عدم محاولة الإضرار بتشغيل التطبيق</li>
            </ul>
          `
        },
        proObligations: {
          title: 'التزامات المحترفين',
          content: `
            <p>يلتزم المحترفون الذين يستخدمون التطبيق بـ:</p>
            <ul>
              <li>امتلاك المؤهلات والتراخيص اللازمة لنشاطهم</li>
              <li>تقديم معلومات دقيقة عن خدماتهم وأسعارهم</li>
              <li>الوفاء بالمواعيد المحجوزة عبر التطبيق</li>
              <li>احترام سرية معلومات المستخدمين وحيواناتهم</li>
              <li>الامتثال للقواعد الأخلاقية لمهنتهم</li>
            </ul>
          `
        },
        payments: {
          title: 'التسعير والمدفوعات',
          content: `
            <p><strong>للمستخدمين:</strong></p>
            <ul>
              <li>التسجيل واستخدام الميزات الأساسية مجاني</li>
              <li>يتم فوترة خدمات المحترفين وفقًا لأسعارهم الخاصة</li>
              <li>يتم الدفع مباشرة للمحترف أو عبر التطبيق</li>
            </ul>
            <p><strong>للمحترفين:</strong></p>
            <ul>
              <li>يتم خصم عمولة قدرها <strong>100 دج</strong> على كل حجز يتم عبر التطبيق</li>
              <li>يتم دفع الأرباح شهريًا وفقًا للشروط المتفق عليها</li>
            </ul>
            <p><strong>سياسة الإلغاء:</strong></p>
            <ul>
              <li>يجب إجراء الإلغاءات قبل 24 ساعة على الأقل من الموعد</li>
              <li>قد تطبق رسوم على الإلغاء المتأخر أو عدم الحضور</li>
            </ul>
          `
        },
        responsibility: {
          title: 'مسؤولية VEGECE',
          content: `
            <p>تعمل VEGECE كـ <strong>وسيط تقني</strong> بين المستخدمين والمحترفين.</p>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-exclamation-triangle"></i> حدود المسؤولية</div>
              <div class="legal-info-card-content">
                <p>VEGECE ليست مسؤولة عن:</p>
                <ul>
                  <li>الأفعال أو النصائح أو العلاجات المقدمة من المحترفين</li>
                  <li>جودة الخدمات المقدمة من المحترفين</li>
                  <li>النزاعات بين المستخدمين والمحترفين</li>
                  <li>الأضرار التي تلحق بالحيوانات أثناء الاستشارات أو الحضانة</li>
                </ul>
              </div>
            </div>
          `
        },
        intellectual: {
          title: 'الملكية الفكرية',
          content: `
            <p>جميع عناصر التطبيق (العلامة التجارية، الشعار، التصميم، الكود، المحتوى) هي ملكية حصرية لـ VEGECE SAS.</p>
            <p><strong>ترخيص الاستخدام:</strong></p>
            <ul>
              <li>تمنحك VEGECE ترخيصًا شخصيًا وغير حصري وغير قابل للتحويل لاستخدام التطبيق</li>
              <li>هذا الترخيص محدود للاستخدام الشخصي وغير التجاري فقط</li>
            </ul>
          `
        },
        suspension: {
          title: 'التعليق والإنهاء',
          content: `
            <p>تحتفظ VEGECE بالحق في تعليق أو إنهاء حسابك في حالة:</p>
            <ul>
              <li>عدم الامتثال لهذه الشروط</li>
              <li>السلوك الاحتيالي أو المسيء</li>
              <li>نشر محتوى غير قانوني</li>
              <li>عدم دفع المبالغ المستحقة (للمحترفين)</li>
              <li>عدم نشاط الحساب لفترة طويلة (أكثر من 24 شهرًا)</li>
            </ul>
          `
        },
        modifications: {
          title: 'تعديلات الشروط',
          content: `
            <p>تحتفظ VEGECE بالحق في تعديل هذه الشروط في أي وقت.</p>
            <p>في حالة التعديل الجوهري:</p>
            <ul>
              <li>سيتم إبلاغك عبر البريد الإلكتروني أو إشعار في التطبيق</li>
              <li>ستُمنح فترة 30 يومًا لمراجعة التعديلات</li>
              <li>الاستمرار في استخدام التطبيق يعني قبول الشروط الجديدة</li>
            </ul>
          `
        },
        law: {
          title: 'القانون المطبق والنزاعات',
          content: `
            <p>تخضع هذه الشروط لـ <strong>القانون الجزائري</strong>.</p>
            <p>في حالة النزاع:</p>
            <ol>
              <li><strong>الوساطة:</strong> نشجعك على التواصل معنا أولاً لمحاولة حل النزاع وديًا</li>
              <li><strong>الاختصاص القضائي:</strong> في حالة عدم التوصل لحل ودي، ستكون المحاكم الجزائرية وحدها المختصة</li>
            </ol>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-envelope"></i> اتصل بنا</div>
              <div class="legal-info-card-content">
                <p>لأي أسئلة حول هذه الشروط: <a href="mailto:legal@vegece.com">legal@vegece.com</a></p>
              </div>
            </div>
          `
        }
      }
    }
  };

  const t = content[language];

  return (
    <LegalLayout title={t.title} subtitle={t.subtitle}>
      <div className="legal-last-update">
        <i className="fa-solid fa-clock"></i>
        {t.lastUpdate}
      </div>

      {Object.entries(t.sections).map(([key, section]) => (
        <section key={key} className="legal-section">
          <h2 className="legal-section-title">
            <i className={`fa-solid ${
              key === 'object' ? 'fa-file-contract' :
              key === 'services' ? 'fa-concierge-bell' :
              key === 'registration' ? 'fa-user-plus' :
              key === 'userObligations' ? 'fa-user-check' :
              key === 'proObligations' ? 'fa-user-tie' :
              key === 'payments' ? 'fa-credit-card' :
              key === 'responsibility' ? 'fa-shield-halved' :
              key === 'intellectual' ? 'fa-copyright' :
              key === 'suspension' ? 'fa-ban' :
              key === 'modifications' ? 'fa-pen-to-square' :
              'fa-gavel'
            }`}></i>
            {section.title}
          </h2>
          <div
            className="legal-section-content"
            dangerouslySetInnerHTML={{ __html: section.content }}
          />
        </section>
      ))}
    </LegalLayout>
  );
}

export default TermsPage;
