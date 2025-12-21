import { useEffect } from 'react';
import { LegalLayout } from './LegalLayout';
import { useLanguage } from '../i18n';

export function LegalNoticePage() {
  const { language } = useLanguage();

  useEffect(() => {
    // Charger FontAwesome
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
      title: 'Mentions Légales',
      subtitle: 'Informations légales relatives à l\'éditeur et à l\'hébergement du site VEGECE',
      lastUpdate: 'Dernière mise à jour : Décembre 2025',
      sections: {
        editor: {
          title: 'Éditeur du site',
          content: `
            <p><strong>VEGECE</strong> est édité par :</p>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-building"></i> Informations de l'entreprise</div>
              <div class="legal-info-card-content">
                <p><strong>Raison sociale :</strong> VEGECE SAS</p>
                <p><strong>Forme juridique :</strong> Société par Actions Simplifiée</p>
                <p><strong>Siège social :</strong> Alger, Algérie</p>
                <p><strong>Email :</strong> contact@vegece.com</p>
                <p><strong>Téléphone :</strong> +213 XX XX XX XX</p>
              </div>
            </div>
          `
        },
        director: {
          title: 'Directeur de la publication',
          content: `
            <p>Le directeur de la publication du site VEGECE est le représentant légal de la société VEGECE SAS.</p>
            <p>Pour toute question relative au contenu du site, vous pouvez nous contacter à l'adresse : <a href="mailto:contact@vegece.com">contact@vegece.com</a></p>
          `
        },
        hosting: {
          title: 'Hébergement',
          content: `
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-server"></i> Hébergeur du site</div>
              <div class="legal-info-card-content">
                <p><strong>Nom :</strong> OVH SAS</p>
                <p><strong>Adresse :</strong> 2 rue Kellermann, 59100 Roubaix, France</p>
                <p><strong>Téléphone :</strong> +33 9 72 10 10 07</p>
                <p><strong>Site web :</strong> <a href="https://www.ovhcloud.com" target="_blank" rel="noopener noreferrer">www.ovhcloud.com</a></p>
              </div>
            </div>
          `
        },
        intellectual: {
          title: 'Propriété intellectuelle',
          content: `
            <p>L'ensemble du contenu du site VEGECE (textes, images, graphismes, logo, icônes, sons, logiciels, etc.) est la propriété exclusive de VEGECE SAS, à l'exception des marques, logos ou contenus appartenant à d'autres sociétés partenaires ou auteurs.</p>
            <p>Toute reproduction, distribution, modification, adaptation, retransmission ou publication, même partielle, de ces différents éléments est strictement interdite sans l'accord exprès par écrit de VEGECE SAS.</p>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-copyright"></i> Droits d'auteur</div>
              <div class="legal-info-card-content">
                <p>Conformément aux dispositions du Code de la propriété intellectuelle, seule l'utilisation pour un usage privé est autorisée. Toute autre utilisation est constitutive de contrefaçon et sanctionnée par la loi.</p>
              </div>
            </div>
          `
        },
        responsibility: {
          title: 'Responsabilité',
          content: `
            <p>VEGECE SAS s'efforce d'assurer l'exactitude et la mise à jour des informations diffusées sur ce site. Cependant, VEGECE SAS ne peut garantir l'exactitude, la précision ou l'exhaustivité des informations mises à disposition sur ce site.</p>
            <p>En conséquence, VEGECE SAS décline toute responsabilité :</p>
            <ul>
              <li>Pour toute imprécision, inexactitude ou omission portant sur des informations disponibles sur le site</li>
              <li>Pour tous dommages résultant d'une intrusion frauduleuse d'un tiers ayant entraîné une modification des informations mises à disposition sur le site</li>
              <li>Pour tous dommages, directs ou indirects, qu'elles qu'en soient les causes, origines, natures ou conséquences</li>
            </ul>
          `
        },
        links: {
          title: 'Liens hypertextes',
          content: `
            <p>Le site VEGECE peut contenir des liens hypertextes vers d'autres sites internet. VEGECE SAS n'exerce aucun contrôle sur ces sites et décline toute responsabilité quant à leur contenu.</p>
            <p>La mise en place de liens hypertextes vers le site VEGECE nécessite une autorisation préalable et écrite de VEGECE SAS.</p>
          `
        },
        litigation: {
          title: 'Droit applicable et juridiction',
          content: `
            <p>Les présentes mentions légales sont régies par le droit algérien.</p>
            <p>En cas de litige, et après l'échec de toute tentative de recherche d'une solution amiable, les tribunaux algériens seront seuls compétents pour connaître de ce litige.</p>
          `
        }
      }
    },
    en: {
      title: 'Legal Notice',
      subtitle: 'Legal information regarding the publisher and hosting of the VEGECE website',
      lastUpdate: 'Last updated: December 2025',
      sections: {
        editor: {
          title: 'Website Publisher',
          content: `
            <p><strong>VEGECE</strong> is published by:</p>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-building"></i> Company Information</div>
              <div class="legal-info-card-content">
                <p><strong>Company name:</strong> VEGECE SAS</p>
                <p><strong>Legal form:</strong> Simplified Joint Stock Company</p>
                <p><strong>Headquarters:</strong> Algiers, Algeria</p>
                <p><strong>Email:</strong> contact@vegece.com</p>
                <p><strong>Phone:</strong> +213 XX XX XX XX</p>
              </div>
            </div>
          `
        },
        director: {
          title: 'Publication Director',
          content: `
            <p>The publication director of the VEGECE website is the legal representative of VEGECE SAS.</p>
            <p>For any questions regarding the site content, you can contact us at: <a href="mailto:contact@vegece.com">contact@vegece.com</a></p>
          `
        },
        hosting: {
          title: 'Hosting',
          content: `
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-server"></i> Website Host</div>
              <div class="legal-info-card-content">
                <p><strong>Name:</strong> OVH SAS</p>
                <p><strong>Address:</strong> 2 rue Kellermann, 59100 Roubaix, France</p>
                <p><strong>Phone:</strong> +33 9 72 10 10 07</p>
                <p><strong>Website:</strong> <a href="https://www.ovhcloud.com" target="_blank" rel="noopener noreferrer">www.ovhcloud.com</a></p>
              </div>
            </div>
          `
        },
        intellectual: {
          title: 'Intellectual Property',
          content: `
            <p>All content on the VEGECE website (texts, images, graphics, logo, icons, sounds, software, etc.) is the exclusive property of VEGECE SAS, except for trademarks, logos, or content belonging to other partner companies or authors.</p>
            <p>Any reproduction, distribution, modification, adaptation, retransmission, or publication, even partial, of these elements is strictly prohibited without the express written consent of VEGECE SAS.</p>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-copyright"></i> Copyright</div>
              <div class="legal-info-card-content">
                <p>In accordance with intellectual property laws, only private use is authorized. Any other use constitutes infringement and is punishable by law.</p>
              </div>
            </div>
          `
        },
        responsibility: {
          title: 'Liability',
          content: `
            <p>VEGECE SAS strives to ensure the accuracy and updating of the information published on this site. However, VEGECE SAS cannot guarantee the accuracy, precision, or completeness of the information made available on this site.</p>
            <p>Consequently, VEGECE SAS declines all responsibility:</p>
            <ul>
              <li>For any inaccuracy, error, or omission regarding the information available on the site</li>
              <li>For any damage resulting from fraudulent intrusion by a third party that has led to a modification of the information made available on the site</li>
              <li>For any direct or indirect damage, regardless of its causes, origins, nature, or consequences</li>
            </ul>
          `
        },
        links: {
          title: 'Hyperlinks',
          content: `
            <p>The VEGECE website may contain hyperlinks to other websites. VEGECE SAS has no control over these sites and declines all responsibility for their content.</p>
            <p>Setting up hyperlinks to the VEGECE website requires prior written authorization from VEGECE SAS.</p>
          `
        },
        litigation: {
          title: 'Applicable Law and Jurisdiction',
          content: `
            <p>These legal notices are governed by Algerian law.</p>
            <p>In case of dispute, and after the failure of any attempt to find an amicable solution, Algerian courts will have sole jurisdiction to hear the dispute.</p>
          `
        }
      }
    },
    ar: {
      title: 'إشعار قانوني',
      subtitle: 'المعلومات القانونية المتعلقة بناشر واستضافة موقع VEGECE',
      lastUpdate: 'آخر تحديث: ديسمبر 2025',
      sections: {
        editor: {
          title: 'ناشر الموقع',
          content: `
            <p><strong>VEGECE</strong> يتم نشره بواسطة:</p>
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-building"></i> معلومات الشركة</div>
              <div class="legal-info-card-content">
                <p><strong>اسم الشركة:</strong> VEGECE SAS</p>
                <p><strong>الشكل القانوني:</strong> شركة مساهمة مبسطة</p>
                <p><strong>المقر الرئيسي:</strong> الجزائر العاصمة، الجزائر</p>
                <p><strong>البريد الإلكتروني:</strong> contact@vegece.com</p>
                <p><strong>الهاتف:</strong> +213 XX XX XX XX</p>
              </div>
            </div>
          `
        },
        director: {
          title: 'مدير النشر',
          content: `
            <p>مدير نشر موقع VEGECE هو الممثل القانوني لشركة VEGECE SAS.</p>
            <p>لأي أسئلة تتعلق بمحتوى الموقع، يمكنكم التواصل معنا على: <a href="mailto:contact@vegece.com">contact@vegece.com</a></p>
          `
        },
        hosting: {
          title: 'الاستضافة',
          content: `
            <div class="legal-info-card">
              <div class="legal-info-card-title"><i class="fa-solid fa-server"></i> مستضيف الموقع</div>
              <div class="legal-info-card-content">
                <p><strong>الاسم:</strong> OVH SAS</p>
                <p><strong>العنوان:</strong> 2 rue Kellermann, 59100 Roubaix, France</p>
                <p><strong>الهاتف:</strong> +33 9 72 10 10 07</p>
                <p><strong>الموقع:</strong> <a href="https://www.ovhcloud.com" target="_blank" rel="noopener noreferrer">www.ovhcloud.com</a></p>
              </div>
            </div>
          `
        },
        intellectual: {
          title: 'الملكية الفكرية',
          content: `
            <p>جميع محتويات موقع VEGECE (النصوص، الصور، الرسومات، الشعار، الأيقونات، الأصوات، البرامج، إلخ) هي ملكية حصرية لشركة VEGECE SAS، باستثناء العلامات التجارية أو الشعارات أو المحتويات التابعة لشركات شريكة أخرى أو مؤلفين آخرين.</p>
            <p>يُمنع منعاً باتاً أي نسخ أو توزيع أو تعديل أو نقل أو نشر، حتى جزئياً، لهذه العناصر دون موافقة كتابية صريحة من VEGECE SAS.</p>
            <div class="legal-info-card highlight">
              <div class="legal-info-card-title"><i class="fa-solid fa-copyright"></i> حقوق النشر</div>
              <div class="legal-info-card-content">
                <p>وفقاً لقوانين الملكية الفكرية، يُسمح فقط بالاستخدام الخاص. أي استخدام آخر يشكل تعدياً ويعاقب عليه القانون.</p>
              </div>
            </div>
          `
        },
        responsibility: {
          title: 'المسؤولية',
          content: `
            <p>تسعى VEGECE SAS لضمان دقة وتحديث المعلومات المنشورة على هذا الموقع. ومع ذلك، لا تستطيع VEGECE SAS ضمان دقة أو صحة أو اكتمال المعلومات المتاحة على هذا الموقع.</p>
            <p>وبالتالي، تخلي VEGECE SAS مسؤوليتها:</p>
            <ul>
              <li>عن أي عدم دقة أو خطأ أو إغفال يتعلق بالمعلومات المتاحة على الموقع</li>
              <li>عن أي ضرر ناتج عن اختراق احتيالي من طرف ثالث أدى إلى تعديل المعلومات المتاحة على الموقع</li>
              <li>عن أي ضرر مباشر أو غير مباشر، مهما كانت أسبابه أو أصوله أو طبيعته أو عواقبه</li>
            </ul>
          `
        },
        links: {
          title: 'الروابط التشعبية',
          content: `
            <p>قد يحتوي موقع VEGECE على روابط تشعبية لمواقع أخرى. VEGECE SAS ليس لديها أي سيطرة على هذه المواقع وتخلي مسؤوليتها عن محتواها.</p>
            <p>يتطلب إنشاء روابط تشعبية لموقع VEGECE الحصول على إذن كتابي مسبق من VEGECE SAS.</p>
          `
        },
        litigation: {
          title: 'القانون المطبق والاختصاص القضائي',
          content: `
            <p>يخضع هذا الإشعار القانوني للقانون الجزائري.</p>
            <p>في حالة النزاع، وبعد فشل أي محاولة لإيجاد حل ودي، ستكون المحاكم الجزائرية وحدها المختصة للنظر في النزاع.</p>
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
              key === 'editor' ? 'fa-building' :
              key === 'director' ? 'fa-user-tie' :
              key === 'hosting' ? 'fa-server' :
              key === 'intellectual' ? 'fa-copyright' :
              key === 'responsibility' ? 'fa-shield-halved' :
              key === 'links' ? 'fa-link' :
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

export default LegalNoticePage;
