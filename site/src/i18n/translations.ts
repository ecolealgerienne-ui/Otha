export type Language = 'fr' | 'en' | 'ar';

export interface Translations {
  // Navigation
  nav: {
    presentation: string;
    about: string;
    download: string;
    professional: string;
  };
  // Hero
  hero: {
    slogan: string;
    scrollDown: string;
  };
  // Showcase
  showcase: {
    headline: string;
    subtext: string;
    benefits: {
      noForget: {
        title: string;
        desc: string;
      };
      centralized: {
        title: string;
        desc: string;
      };
      saveTime: {
        title: string;
        desc: string;
      };
    };
  };
  // Features (About section)
  features: {
    findNearby: {
      title: string;
      desc: string;
    };
    allPets: {
      title: string;
      desc: string;
    };
    easyBooking: {
      title: string;
      desc: string;
    };
    healthRecord: {
      title: string;
      desc: string;
    };
    adoption: {
      title: string;
      desc: string;
    };
    daycare: {
      title: string;
      desc: string;
    };
  };
  // Download
  download: {
    label: string;
    title: string;
    desc: string;
    appStore: string;
    googlePlay: string;
    downloadOn: string;
    availableOn: string;
    stats: {
      downloads: string;
      rating: string;
      vets: string;
    };
  };
  // Footer
  footer: {
    tagline: string;
    navigation: string;
    home: string;
    support: string;
    helpCenter: string;
    contact: string;
    faq: string;
    followUs: string;
    copyright: string;
    legal: string;
    privacy: string;
    terms: string;
  };
}

export const translations: Record<Language, Translations> = {
  fr: {
    nav: {
      presentation: 'Présentation',
      about: 'A propos',
      download: 'Téléchargement',
      professional: 'Vous êtes un professionnel ?',
    },
    hero: {
      slogan: 'La santé de votre animal, simplifiée',
      scrollDown: 'Défiler vers le bas',
    },
    showcase: {
      headline: 'Parce qu\'ils comptent\nsur vous',
      subtext: 'Offrez-leur le meilleur avec une gestion simplifiée de leur santé et bien-être.',
      benefits: {
        noForget: {
          title: 'Fini les oublis',
          desc: 'Rappels automatiques pour les vaccins et rendez-vous',
        },
        centralized: {
          title: 'Tout centralisé',
          desc: 'Carnet de santé, ordonnances, historique médical',
        },
        saveTime: {
          title: 'Gagnez du temps',
          desc: 'Trouvez un vétérinaire et réservez en 30 secondes',
        },
      },
    },
    features: {
      findNearby: {
        title: 'Trouvez autour de vous',
        desc: 'Vétérinaires, garderies, pet shops près de chez vous',
      },
      allPets: {
        title: 'Tous vos animaux',
        desc: 'Chiens, chats, NAC... gérez tous vos compagnons',
      },
      easyBooking: {
        title: 'Rendez-vous facile',
        desc: 'Réservez en quelques clics chez votre vétérinaire',
      },
      healthRecord: {
        title: 'Carnet de santé',
        desc: 'Vaccins, ordonnances, historique médical centralisé',
      },
      adoption: {
        title: 'Adoption',
        desc: 'Trouvez votre futur compagnon ou proposez à l\'adoption',
      },
      daycare: {
        title: 'Garderie',
        desc: 'Trouvez une garderie de confiance pour vos absences',
      },
    },
    download: {
      label: 'Téléchargement',
      title: 'Prêt à simplifier\nla vie de vos animaux ?',
      desc: 'Rejoignez des milliers de propriétaires qui font confiance à VEGECE pour prendre soin de leurs compagnons.',
      appStore: 'App Store',
      googlePlay: 'Google Play',
      downloadOn: 'Télécharger sur',
      availableOn: 'Disponible sur',
      stats: {
        downloads: 'Téléchargements',
        rating: 'Note moyenne',
        vets: 'Vétérinaires',
      },
    },
    footer: {
      tagline: 'La santé de vos animaux, simplifiée. Tout ce dont vous avez besoin, en une seule application.',
      navigation: 'Navigation',
      home: 'Accueil',
      support: 'Support',
      helpCenter: 'Centre d\'aide',
      contact: 'Contact',
      faq: 'FAQ',
      followUs: 'Suivez-nous',
      copyright: '© 2025 VEGECE. Tous droits réservés.',
      legal: 'Mentions légales',
      privacy: 'Politique de confidentialité',
      terms: 'CGU',
    },
  },
  en: {
    nav: {
      presentation: 'Features',
      about: 'About',
      download: 'Download',
      professional: 'Are you a professional?',
    },
    hero: {
      slogan: 'Your pet\'s health, simplified',
      scrollDown: 'Scroll down',
    },
    showcase: {
      headline: 'Because they count\non you',
      subtext: 'Give them the best with simplified health and wellness management.',
      benefits: {
        noForget: {
          title: 'No more forgetting',
          desc: 'Automatic reminders for vaccines and appointments',
        },
        centralized: {
          title: 'All centralized',
          desc: 'Health record, prescriptions, medical history',
        },
        saveTime: {
          title: 'Save time',
          desc: 'Find a vet and book in 30 seconds',
        },
      },
    },
    features: {
      findNearby: {
        title: 'Find nearby',
        desc: 'Vets, daycares, pet shops near you',
      },
      allPets: {
        title: 'All your pets',
        desc: 'Dogs, cats, exotic pets... manage all your companions',
      },
      easyBooking: {
        title: 'Easy booking',
        desc: 'Book your vet appointment in a few clicks',
      },
      healthRecord: {
        title: 'Health record',
        desc: 'Vaccines, prescriptions, centralized medical history',
      },
      adoption: {
        title: 'Adoption',
        desc: 'Find your future companion or offer for adoption',
      },
      daycare: {
        title: 'Daycare',
        desc: 'Find a trusted daycare for when you\'re away',
      },
    },
    download: {
      label: 'Download',
      title: 'Ready to simplify\nyour pets\' life?',
      desc: 'Join thousands of pet owners who trust VEGECE to take care of their companions.',
      appStore: 'App Store',
      googlePlay: 'Google Play',
      downloadOn: 'Download on',
      availableOn: 'Available on',
      stats: {
        downloads: 'Downloads',
        rating: 'Average rating',
        vets: 'Veterinarians',
      },
    },
    footer: {
      tagline: 'Your pets\' health, simplified. Everything you need, in one app.',
      navigation: 'Navigation',
      home: 'Home',
      support: 'Support',
      helpCenter: 'Help Center',
      contact: 'Contact',
      faq: 'FAQ',
      followUs: 'Follow us',
      copyright: '© 2025 VEGECE. All rights reserved.',
      legal: 'Legal notice',
      privacy: 'Privacy policy',
      terms: 'Terms of use',
    },
  },
  ar: {
    nav: {
      presentation: 'المميزات',
      about: 'حول',
      download: 'تحميل',
      professional: 'هل أنت محترف؟',
    },
    hero: {
      slogan: 'صحة حيوانك الأليف، بكل بساطة',
      scrollDown: 'انتقل للأسفل',
    },
    showcase: {
      headline: 'لأنهم يعتمدون\nعليك',
      subtext: 'امنحهم الأفضل مع إدارة مبسطة لصحتهم ورفاهيتهم.',
      benefits: {
        noForget: {
          title: 'لا مزيد من النسيان',
          desc: 'تذكيرات تلقائية للقاحات والمواعيد',
        },
        centralized: {
          title: 'كل شيء في مكان واحد',
          desc: 'السجل الصحي، الوصفات، التاريخ الطبي',
        },
        saveTime: {
          title: 'وفر وقتك',
          desc: 'ابحث عن طبيب بيطري واحجز في 30 ثانية',
        },
      },
    },
    features: {
      findNearby: {
        title: 'ابحث بالقرب منك',
        desc: 'أطباء بيطريون، حضانات، متاجر حيوانات قريبة منك',
      },
      allPets: {
        title: 'جميع حيواناتك',
        desc: 'كلاب، قطط، حيوانات غريبة... أدر جميع رفاقك',
      },
      easyBooking: {
        title: 'حجز سهل',
        desc: 'احجز موعدك مع الطبيب البيطري بنقرات قليلة',
      },
      healthRecord: {
        title: 'السجل الصحي',
        desc: 'اللقاحات، الوصفات، التاريخ الطبي المركزي',
      },
      adoption: {
        title: 'التبني',
        desc: 'ابحث عن رفيقك المستقبلي أو اعرض للتبني',
      },
      daycare: {
        title: 'الحضانة',
        desc: 'ابحث عن حضانة موثوقة أثناء غيابك',
      },
    },
    download: {
      label: 'تحميل',
      title: 'مستعد لتبسيط\nحياة حيواناتك؟',
      desc: 'انضم إلى آلاف أصحاب الحيوانات الذين يثقون بـ VEGECE للعناية برفاقهم.',
      appStore: 'App Store',
      googlePlay: 'Google Play',
      downloadOn: 'تحميل من',
      availableOn: 'متوفر على',
      stats: {
        downloads: 'تحميلات',
        rating: 'متوسط التقييم',
        vets: 'أطباء بيطريون',
      },
    },
    footer: {
      tagline: 'صحة حيواناتك، بكل بساطة. كل ما تحتاجه، في تطبيق واحد.',
      navigation: 'التنقل',
      home: 'الرئيسية',
      support: 'الدعم',
      helpCenter: 'مركز المساعدة',
      contact: 'اتصل بنا',
      faq: 'الأسئلة الشائعة',
      followUs: 'تابعنا',
      copyright: '© 2025 VEGECE. جميع الحقوق محفوظة.',
      legal: 'إشعار قانوني',
      privacy: 'سياسة الخصوصية',
      terms: 'شروط الاستخدام',
    },
  },
};
