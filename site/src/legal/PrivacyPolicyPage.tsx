import { useEffect } from 'react';
import { LegalLayout } from './LegalLayout';
import { useLanguage } from '../i18n';

export function PrivacyPolicyPage() {
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
      title: 'Politique de Confidentialité',
      subtitle: 'Comment nous collectons, utilisons et protégeons vos données personnelles',
      lastUpdate: 'Dernière mise à jour : Décembre 2025',
      sections: {
        intro: {
          title: 'Introduction',
          content: `
            <p>Chez VEGECE, nous accordons une importance primordiale à la protection de vos données personnelles. Cette politique de confidentialité explique comment nous collectons, utilisons, stockons et protégeons vos informations lorsque vous utilisez notre application et nos services.</p>
            <p>En utilisant VEGECE, vous acceptez les pratiques décrites dans cette politique.</p>
          `
        },
        dataCollected: {
          title: 'Données collectées',
          content: `
            <p>Nous collectons différents types de données pour vous fournir nos services :</p>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-user"></i> Données personnelles</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>Informations d'identification :</strong> nom, prénom, adresse email, numéro de téléphone</li>
                  <li><strong>Données de compte :</strong> mot de passe (chiffré), photo de profil</li>
                  <li><strong>Informations de localisation :</strong> adresse, coordonnées GPS (avec votre consentement)</li>
                </ul>
              </div>
            </div>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-paw"></i> Données relatives à vos animaux</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>Informations d'identification :</strong> nom, espèce, race, date de naissance, sexe</li>
                  <li><strong>Données de santé :</strong> poids, groupe sanguin, numéro de puce électronique</li>
                  <li><strong>Historique médical :</strong> vaccinations, maladies, prescriptions, consultations</li>
                  <li><strong>Photos :</strong> photos de votre animal</li>
                </ul>
              </div>
            </div>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-mobile-screen"></i> Données d'utilisation</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>Données techniques :</strong> type d'appareil, système d'exploitation, adresse IP</li>
                  <li><strong>Données de navigation :</strong> pages visitées, fonctionnalités utilisées</li>
                  <li><strong>Historique :</strong> réservations, interactions avec les professionnels</li>
                </ul>
              </div>
            </div>
          `
        },
        purposes: {
          title: 'Finalités du traitement',
          content: `
            <p>Vos données sont utilisées pour les finalités suivantes :</p>
            <table class="legal-table">
              <thead>
                <tr>
                  <th>Finalité</th>
                  <th>Base légale</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Création et gestion de votre compte</td>
                  <td>Exécution du contrat</td>
                </tr>
                <tr>
                  <td>Réservation de services vétérinaires</td>
                  <td>Exécution du contrat</td>
                </tr>
                <tr>
                  <td>Suivi de la santé de vos animaux</td>
                  <td>Exécution du contrat</td>
                </tr>
                <tr>
                  <td>Envoi de rappels (vaccins, rendez-vous)</td>
                  <td>Intérêt légitime</td>
                </tr>
                <tr>
                  <td>Géolocalisation des professionnels</td>
                  <td>Consentement</td>
                </tr>
                <tr>
                  <td>Amélioration de nos services</td>
                  <td>Intérêt légitime</td>
                </tr>
                <tr>
                  <td>Communications marketing</td>
                  <td>Consentement</td>
                </tr>
              </tbody>
            </table>
          `
        },
        sharing: {
          title: 'Partage des données',
          content: `
            <p>Vos données peuvent être partagées avec :</p>
            <ul>
              <li><strong>Les professionnels vétérinaires :</strong> uniquement les informations nécessaires à la consultation de votre animal</li>
              <li><strong>Les garderies partenaires :</strong> informations relatives à la garde de votre animal</li>
              <li><strong>Nos prestataires techniques :</strong> hébergement, paiement (ces prestataires sont contractuellement tenus de protéger vos données)</li>
            </ul>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-shield-halved"></i> Nous ne vendons jamais vos données</div>
              <div class="legal-info-card-content">
                <p>VEGECE ne vend, ne loue et ne partage jamais vos données personnelles à des fins commerciales ou publicitaires avec des tiers.</p>
              </div>
            </div>
          `
        },
        retention: {
          title: 'Durée de conservation',
          content: `
            <p>Vos données sont conservées pour les durées suivantes :</p>
            <table class="legal-table">
              <thead>
                <tr>
                  <th>Type de données</th>
                  <th>Durée de conservation</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Données de compte</td>
                  <td>Durée de vie du compte + 3 ans</td>
                </tr>
                <tr>
                  <td>Historique médical des animaux</td>
                  <td>10 ans après la dernière mise à jour</td>
                </tr>
                <tr>
                  <td>Historique des réservations</td>
                  <td>5 ans</td>
                </tr>
                <tr>
                  <td>Données de facturation</td>
                  <td>10 ans (obligations légales)</td>
                </tr>
                <tr>
                  <td>Cookies et données techniques</td>
                  <td>13 mois maximum</td>
                </tr>
              </tbody>
            </table>
          `
        },
        rights: {
          title: 'Vos droits',
          content: `
            <p>Conformément à la réglementation en vigueur, vous disposez des droits suivants :</p>
            <ul>
              <li><strong>Droit d'accès :</strong> obtenir une copie de vos données personnelles</li>
              <li><strong>Droit de rectification :</strong> corriger des données inexactes</li>
              <li><strong>Droit à l'effacement :</strong> demander la suppression de vos données</li>
              <li><strong>Droit à la portabilité :</strong> recevoir vos données dans un format structuré</li>
              <li><strong>Droit d'opposition :</strong> vous opposer au traitement de vos données</li>
              <li><strong>Droit de limitation :</strong> limiter le traitement de vos données</li>
            </ul>
            <p>Pour exercer ces droits, contactez-nous à : <a href="mailto:privacy@vegece.com">privacy@vegece.com</a></p>
          `
        },
        security: {
          title: 'Sécurité des données',
          content: `
            <p>Nous mettons en œuvre des mesures de sécurité techniques et organisationnelles pour protéger vos données :</p>
            <ul>
              <li><strong>Chiffrement :</strong> toutes les données sont chiffrées en transit (HTTPS) et au repos</li>
              <li><strong>Authentification :</strong> mots de passe hashés avec des algorithmes sécurisés</li>
              <li><strong>Accès restreint :</strong> seuls les employés autorisés ont accès aux données</li>
              <li><strong>Surveillance :</strong> monitoring continu des systèmes</li>
              <li><strong>Sauvegardes :</strong> sauvegardes régulières et sécurisées</li>
            </ul>
          `
        },
        cookies: {
          title: 'Cookies',
          content: `
            <p>Notre application utilise des cookies et technologies similaires pour :</p>
            <ul>
              <li><strong>Cookies essentiels :</strong> fonctionnement du site, authentification</li>
              <li><strong>Cookies de préférences :</strong> mémorisation de vos choix (langue, thème)</li>
              <li><strong>Cookies analytiques :</strong> amélioration de nos services (avec votre consentement)</li>
            </ul>
            <p>Vous pouvez gérer vos préférences de cookies dans les paramètres de votre navigateur.</p>
          `
        },
        contact: {
          title: 'Contact',
          content: `
            <p>Pour toute question concernant cette politique de confidentialité ou vos données personnelles :</p>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-envelope"></i> Délégué à la protection des données</div>
              <div class="legal-info-card-content">
                <p><strong>Email :</strong> <a href="mailto:privacy@vegece.com">privacy@vegece.com</a></p>
                <p><strong>Adresse :</strong> VEGECE SAS - Protection des données - Alger, Algérie</p>
              </div>
            </div>
          `
        }
      }
    },
    en: {
      title: 'Privacy Policy',
      subtitle: 'How we collect, use, and protect your personal data',
      lastUpdate: 'Last updated: December 2025',
      sections: {
        intro: {
          title: 'Introduction',
          content: `
            <p>At VEGECE, we place the utmost importance on protecting your personal data. This privacy policy explains how we collect, use, store, and protect your information when you use our application and services.</p>
            <p>By using VEGECE, you agree to the practices described in this policy.</p>
          `
        },
        dataCollected: {
          title: 'Data Collected',
          content: `
            <p>We collect different types of data to provide our services:</p>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-user"></i> Personal Data</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>Identification information:</strong> name, email address, phone number</li>
                  <li><strong>Account data:</strong> password (encrypted), profile photo</li>
                  <li><strong>Location information:</strong> address, GPS coordinates (with your consent)</li>
                </ul>
              </div>
            </div>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-paw"></i> Pet Data</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>Identification information:</strong> name, species, breed, date of birth, gender</li>
                  <li><strong>Health data:</strong> weight, blood type, microchip number</li>
                  <li><strong>Medical history:</strong> vaccinations, diseases, prescriptions, consultations</li>
                  <li><strong>Photos:</strong> photos of your pet</li>
                </ul>
              </div>
            </div>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-mobile-screen"></i> Usage Data</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>Technical data:</strong> device type, operating system, IP address</li>
                  <li><strong>Browsing data:</strong> pages visited, features used</li>
                  <li><strong>History:</strong> bookings, interactions with professionals</li>
                </ul>
              </div>
            </div>
          `
        },
        purposes: {
          title: 'Processing Purposes',
          content: `
            <p>Your data is used for the following purposes:</p>
            <table class="legal-table">
              <thead>
                <tr>
                  <th>Purpose</th>
                  <th>Legal Basis</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Account creation and management</td>
                  <td>Contract performance</td>
                </tr>
                <tr>
                  <td>Veterinary service booking</td>
                  <td>Contract performance</td>
                </tr>
                <tr>
                  <td>Pet health tracking</td>
                  <td>Contract performance</td>
                </tr>
                <tr>
                  <td>Sending reminders (vaccines, appointments)</td>
                  <td>Legitimate interest</td>
                </tr>
                <tr>
                  <td>Professional geolocation</td>
                  <td>Consent</td>
                </tr>
                <tr>
                  <td>Service improvement</td>
                  <td>Legitimate interest</td>
                </tr>
                <tr>
                  <td>Marketing communications</td>
                  <td>Consent</td>
                </tr>
              </tbody>
            </table>
          `
        },
        sharing: {
          title: 'Data Sharing',
          content: `
            <p>Your data may be shared with:</p>
            <ul>
              <li><strong>Veterinary professionals:</strong> only information necessary for your pet's consultation</li>
              <li><strong>Partner daycares:</strong> information related to your pet's care</li>
              <li><strong>Technical service providers:</strong> hosting, payment (these providers are contractually required to protect your data)</li>
            </ul>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-shield-halved"></i> We Never Sell Your Data</div>
              <div class="legal-info-card-content">
                <p>VEGECE never sells, rents, or shares your personal data for commercial or advertising purposes with third parties.</p>
              </div>
            </div>
          `
        },
        retention: {
          title: 'Data Retention',
          content: `
            <p>Your data is retained for the following periods:</p>
            <table class="legal-table">
              <thead>
                <tr>
                  <th>Data Type</th>
                  <th>Retention Period</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Account data</td>
                  <td>Account lifetime + 3 years</td>
                </tr>
                <tr>
                  <td>Pet medical history</td>
                  <td>10 years after last update</td>
                </tr>
                <tr>
                  <td>Booking history</td>
                  <td>5 years</td>
                </tr>
                <tr>
                  <td>Billing data</td>
                  <td>10 years (legal requirements)</td>
                </tr>
                <tr>
                  <td>Cookies and technical data</td>
                  <td>13 months maximum</td>
                </tr>
              </tbody>
            </table>
          `
        },
        rights: {
          title: 'Your Rights',
          content: `
            <p>In accordance with applicable regulations, you have the following rights:</p>
            <ul>
              <li><strong>Right of access:</strong> obtain a copy of your personal data</li>
              <li><strong>Right of rectification:</strong> correct inaccurate data</li>
              <li><strong>Right to erasure:</strong> request deletion of your data</li>
              <li><strong>Right to portability:</strong> receive your data in a structured format</li>
              <li><strong>Right to object:</strong> object to the processing of your data</li>
              <li><strong>Right to restriction:</strong> limit the processing of your data</li>
            </ul>
            <p>To exercise these rights, contact us at: <a href="mailto:privacy@vegece.com">privacy@vegece.com</a></p>
          `
        },
        security: {
          title: 'Data Security',
          content: `
            <p>We implement technical and organizational security measures to protect your data:</p>
            <ul>
              <li><strong>Encryption:</strong> all data is encrypted in transit (HTTPS) and at rest</li>
              <li><strong>Authentication:</strong> passwords hashed with secure algorithms</li>
              <li><strong>Restricted access:</strong> only authorized employees have access to data</li>
              <li><strong>Monitoring:</strong> continuous system monitoring</li>
              <li><strong>Backups:</strong> regular and secure backups</li>
            </ul>
          `
        },
        cookies: {
          title: 'Cookies',
          content: `
            <p>Our application uses cookies and similar technologies for:</p>
            <ul>
              <li><strong>Essential cookies:</strong> site functionality, authentication</li>
              <li><strong>Preference cookies:</strong> remembering your choices (language, theme)</li>
              <li><strong>Analytics cookies:</strong> improving our services (with your consent)</li>
            </ul>
            <p>You can manage your cookie preferences in your browser settings.</p>
          `
        },
        contact: {
          title: 'Contact',
          content: `
            <p>For any questions regarding this privacy policy or your personal data:</p>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-envelope"></i> Data Protection Officer</div>
              <div class="legal-info-card-content">
                <p><strong>Email:</strong> <a href="mailto:privacy@vegece.com">privacy@vegece.com</a></p>
                <p><strong>Address:</strong> VEGECE SAS - Data Protection - Algiers, Algeria</p>
              </div>
            </div>
          `
        }
      }
    },
    ar: {
      title: 'سياسة الخصوصية',
      subtitle: 'كيف نجمع ونستخدم ونحمي بياناتك الشخصية',
      lastUpdate: 'آخر تحديث: ديسمبر 2025',
      sections: {
        intro: {
          title: 'مقدمة',
          content: `
            <p>في VEGECE، نولي أهمية قصوى لحماية بياناتك الشخصية. توضح سياسة الخصوصية هذه كيف نجمع ونستخدم ونخزن ونحمي معلوماتك عند استخدام تطبيقنا وخدماتنا.</p>
            <p>باستخدام VEGECE، فإنك توافق على الممارسات الموضحة في هذه السياسة.</p>
          `
        },
        dataCollected: {
          title: 'البيانات المجمعة',
          content: `
            <p>نجمع أنواعًا مختلفة من البيانات لتقديم خدماتنا:</p>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-user"></i> البيانات الشخصية</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>معلومات التعريف:</strong> الاسم، البريد الإلكتروني، رقم الهاتف</li>
                  <li><strong>بيانات الحساب:</strong> كلمة المرور (مشفرة)، صورة الملف الشخصي</li>
                  <li><strong>معلومات الموقع:</strong> العنوان، إحداثيات GPS (بموافقتك)</li>
                </ul>
              </div>
            </div>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-paw"></i> بيانات الحيوانات الأليفة</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>معلومات التعريف:</strong> الاسم، النوع، السلالة، تاريخ الميلاد، الجنس</li>
                  <li><strong>البيانات الصحية:</strong> الوزن، فصيلة الدم، رقم الشريحة الإلكترونية</li>
                  <li><strong>السجل الطبي:</strong> التطعيمات، الأمراض، الوصفات، الاستشارات</li>
                  <li><strong>الصور:</strong> صور حيوانك الأليف</li>
                </ul>
              </div>
            </div>

            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-mobile-screen"></i> بيانات الاستخدام</div>
              <div class="legal-info-card-content">
                <ul>
                  <li><strong>البيانات التقنية:</strong> نوع الجهاز، نظام التشغيل، عنوان IP</li>
                  <li><strong>بيانات التصفح:</strong> الصفحات التي تمت زيارتها، الميزات المستخدمة</li>
                  <li><strong>السجل:</strong> الحجوزات، التفاعلات مع المحترفين</li>
                </ul>
              </div>
            </div>
          `
        },
        purposes: {
          title: 'أغراض المعالجة',
          content: `
            <p>تُستخدم بياناتك للأغراض التالية:</p>
            <table class="legal-table">
              <thead>
                <tr>
                  <th>الغرض</th>
                  <th>الأساس القانوني</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>إنشاء وإدارة حسابك</td>
                  <td>تنفيذ العقد</td>
                </tr>
                <tr>
                  <td>حجز الخدمات البيطرية</td>
                  <td>تنفيذ العقد</td>
                </tr>
                <tr>
                  <td>متابعة صحة حيواناتك</td>
                  <td>تنفيذ العقد</td>
                </tr>
                <tr>
                  <td>إرسال التذكيرات (اللقاحات، المواعيد)</td>
                  <td>المصلحة المشروعة</td>
                </tr>
                <tr>
                  <td>تحديد موقع المحترفين</td>
                  <td>الموافقة</td>
                </tr>
                <tr>
                  <td>تحسين خدماتنا</td>
                  <td>المصلحة المشروعة</td>
                </tr>
              </tbody>
            </table>
          `
        },
        sharing: {
          title: 'مشاركة البيانات',
          content: `
            <p>قد تتم مشاركة بياناتك مع:</p>
            <ul>
              <li><strong>المحترفون البيطريون:</strong> فقط المعلومات اللازمة لاستشارة حيوانك</li>
              <li><strong>الحضانات الشريكة:</strong> المعلومات المتعلقة برعاية حيوانك</li>
              <li><strong>مقدمو الخدمات التقنية:</strong> الاستضافة، الدفع (هؤلاء المقدمون ملزمون تعاقديًا بحماية بياناتك)</li>
            </ul>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-shield-halved"></i> لا نبيع بياناتك أبدًا</div>
              <div class="legal-info-card-content">
                <p>VEGECE لا تبيع أو تؤجر أو تشارك بياناتك الشخصية لأغراض تجارية أو إعلانية مع أطراف ثالثة.</p>
              </div>
            </div>
          `
        },
        retention: {
          title: 'مدة الاحتفاظ',
          content: `
            <p>يتم الاحتفاظ ببياناتك للفترات التالية:</p>
            <table class="legal-table">
              <thead>
                <tr>
                  <th>نوع البيانات</th>
                  <th>مدة الاحتفاظ</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>بيانات الحساب</td>
                  <td>مدة الحساب + 3 سنوات</td>
                </tr>
                <tr>
                  <td>السجل الطبي للحيوانات</td>
                  <td>10 سنوات بعد آخر تحديث</td>
                </tr>
                <tr>
                  <td>سجل الحجوزات</td>
                  <td>5 سنوات</td>
                </tr>
                <tr>
                  <td>بيانات الفواتير</td>
                  <td>10 سنوات (متطلبات قانونية)</td>
                </tr>
              </tbody>
            </table>
          `
        },
        rights: {
          title: 'حقوقك',
          content: `
            <p>وفقًا للوائح المعمول بها، لديك الحقوق التالية:</p>
            <ul>
              <li><strong>حق الوصول:</strong> الحصول على نسخة من بياناتك الشخصية</li>
              <li><strong>حق التصحيح:</strong> تصحيح البيانات غير الدقيقة</li>
              <li><strong>حق المحو:</strong> طلب حذف بياناتك</li>
              <li><strong>حق النقل:</strong> استلام بياناتك بتنسيق منظم</li>
              <li><strong>حق الاعتراض:</strong> الاعتراض على معالجة بياناتك</li>
            </ul>
            <p>لممارسة هذه الحقوق، تواصل معنا على: <a href="mailto:privacy@vegece.com">privacy@vegece.com</a></p>
          `
        },
        security: {
          title: 'أمان البيانات',
          content: `
            <p>ننفذ تدابير أمنية تقنية وتنظيمية لحماية بياناتك:</p>
            <ul>
              <li><strong>التشفير:</strong> جميع البيانات مشفرة أثناء النقل (HTTPS) وعند التخزين</li>
              <li><strong>المصادقة:</strong> كلمات المرور مجزأة بخوارزميات آمنة</li>
              <li><strong>الوصول المقيد:</strong> فقط الموظفون المصرح لهم لديهم حق الوصول</li>
              <li><strong>المراقبة:</strong> مراقبة مستمرة للأنظمة</li>
            </ul>
          `
        },
        cookies: {
          title: 'ملفات تعريف الارتباط',
          content: `
            <p>يستخدم تطبيقنا ملفات تعريف الارتباط والتقنيات المماثلة من أجل:</p>
            <ul>
              <li><strong>ملفات تعريف الارتباط الأساسية:</strong> وظائف الموقع، المصادقة</li>
              <li><strong>ملفات تعريف الارتباط للتفضيلات:</strong> تذكر اختياراتك (اللغة، المظهر)</li>
              <li><strong>ملفات تعريف الارتباط التحليلية:</strong> تحسين خدماتنا (بموافقتك)</li>
            </ul>
          `
        },
        contact: {
          title: 'اتصل بنا',
          content: `
            <p>لأي أسئلة تتعلق بسياسة الخصوصية هذه أو بياناتك الشخصية:</p>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-envelope"></i> مسؤول حماية البيانات</div>
              <div class="legal-info-card-content">
                <p><strong>البريد الإلكتروني:</strong> <a href="mailto:privacy@vegece.com">privacy@vegece.com</a></p>
                <p><strong>العنوان:</strong> VEGECE SAS - حماية البيانات - الجزائر العاصمة، الجزائر</p>
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
              key === 'intro' ? 'fa-circle-info' :
              key === 'dataCollected' ? 'fa-database' :
              key === 'purposes' ? 'fa-bullseye' :
              key === 'sharing' ? 'fa-share-nodes' :
              key === 'retention' ? 'fa-clock' :
              key === 'rights' ? 'fa-user-shield' :
              key === 'security' ? 'fa-lock' :
              key === 'cookies' ? 'fa-cookie-bite' :
              'fa-envelope'
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

export default PrivacyPolicyPage;
