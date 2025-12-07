import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './landing.css';

// Types pour le sélecteur de langue
interface LanguageData {
  lang: string;
  imgSrc: string;
  altText: string;
  dataImg: string;
}

export function LandingPage() {
  const navigate = useNavigate();
  const [isLanguageSelectorOpen, setIsLanguageSelectorOpen] = useState(false);
  const [selectedFeature, setSelectedFeature] = useState(0);

  // Features avec leurs écrans associés
  const features = [
    { icon: 'fa-map-location-dot', title: 'Trouvez autour de vous', desc: 'Vétérinaires, garderies, pet shops près de chez vous', screen: '/assets/img/screens/map.jpeg' },
    { icon: 'fa-paw', title: 'Tous vos animaux', desc: 'Chiens, chats, NAC... gérez tous vos compagnons', screen: '/assets/img/screens/home.jpeg' },
    { icon: 'fa-calendar-check', title: 'Rendez-vous facile', desc: 'Réservez en quelques clics chez votre vétérinaire', screen: '/assets/img/screens/home.jpeg' },
    { icon: 'fa-file-medical', title: 'Carnet de santé', desc: 'Vaccins, ordonnances, historique médical centralisé', screen: '/assets/img/screens/santé.jpeg' },
    { icon: 'fa-heart', title: 'Adoption', desc: 'Trouvez votre futur compagnon ou proposez à l\'adoption', screen: '/assets/img/screens/adopt.jpeg' },
    { icon: 'fa-house', title: 'Garderie', desc: 'Trouvez une garderie de confiance pour vos absences', screen: '/assets/img/screens/home.jpeg' },
  ];

  // État pour les drapeaux
  const [mainFlag, setMainFlag] = useState<LanguageData>({
    lang: 'fr',
    imgSrc: '/assets/img/french.png',
    altText: 'Drapeau Français',
    dataImg: 'france'
  });

  const [subFlags, setSubFlags] = useState<LanguageData[]>([
    {
      lang: 'en',
      imgSrc: '/assets/img/english.png',
      altText: 'Drapeau Anglais',
      dataImg: 'uk'
    },
    {
      lang: 'dz',
      imgSrc: '/assets/img/algeria.png',
      altText: 'Drapeau Algérien',
      dataImg: 'algeria'
    }
  ]);

  // Compteur pour forcer la re-animation à chaque changement
  const [animationKey, setAnimationKey] = useState(0);

  // Gérer le changement de feature avec animation de scroll
  const handleFeatureClick = (index: number) => {
    if (index !== selectedFeature) {
      setSelectedFeature(index);
      setAnimationKey(prev => prev + 1);
    }
  };

  // Charger FontAwesome et configurer le scroll personnalisé
  useEffect(() => {
    // Ajouter classe sur html pour le scroll
    document.documentElement.classList.add('landing-active');

    // Charger FontAwesome
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
    document.head.appendChild(link);

    // Gestionnaire de scroll personnalisé pour une animation lente
    const container = document.querySelector('.landing-page');
    let isScrolling = false;
    let scrollTimeout: ReturnType<typeof setTimeout>;

    const handleWheel = (e: WheelEvent) => {
      if (isScrolling) {
        e.preventDefault();
        return;
      }

      e.preventDefault();
      isScrolling = true;

      const sections = container?.querySelectorAll('.main, .showcase, .about, .download, .footer');
      if (!sections || !container) return;

      const currentScroll = (container as HTMLElement).scrollTop;
      const viewportHeight = window.innerHeight;

      // Trouver la section actuelle
      let currentIndex = 0;
      sections.forEach((section, index) => {
        const sectionTop = (section as HTMLElement).offsetTop;
        if (currentScroll >= sectionTop - viewportHeight / 2) {
          currentIndex = index;
        }
      });

      // Déterminer la direction et la cible
      let targetIndex = currentIndex;
      if (e.deltaY > 0 && currentIndex < sections.length - 1) {
        targetIndex = currentIndex + 1;
      } else if (e.deltaY < 0 && currentIndex > 0) {
        targetIndex = currentIndex - 1;
      }

      if (targetIndex !== currentIndex) {
        const targetSection = sections[targetIndex] as HTMLElement;
        const targetPosition = targetSection.offsetTop;
        const startPosition = (container as HTMLElement).scrollTop;
        const distance = targetPosition - startPosition;
        const duration = 1200; // Animation lente de 1.2 secondes
        let startTime: number | null = null;

        const easeInOutCubic = (t: number): number => {
          return t < 0.5
            ? 4 * t * t * t
            : 1 - Math.pow(-2 * t + 2, 3) / 2;
        };

        const animation = (currentTime: number) => {
          if (startTime === null) startTime = currentTime;
          const timeElapsed = currentTime - startTime;
          const progress = Math.min(timeElapsed / duration, 1);
          const easedProgress = easeInOutCubic(progress);

          (container as HTMLElement).scrollTop = startPosition + distance * easedProgress;

          if (timeElapsed < duration) {
            requestAnimationFrame(animation);
          } else {
            // Permettre un nouveau scroll après un délai
            scrollTimeout = setTimeout(() => {
              isScrolling = false;
            }, 100);
          }
        };

        requestAnimationFrame(animation);
      } else {
        isScrolling = false;
      }
    };

    container?.addEventListener('wheel', handleWheel as EventListener, { passive: false });

    return () => {
      document.documentElement.classList.remove('landing-active');
      document.head.removeChild(link);
      container?.removeEventListener('wheel', handleWheel as EventListener);
      clearTimeout(scrollTimeout);
    };
  }, []);

  // Gestion du clic sur le drapeau principal
  const handleMainFlagClick = () => {
    setIsLanguageSelectorOpen(!isLanguageSelectorOpen);
  };

  // Gestion du changement de langue
  const handleSubFlagClick = (index: number) => {
    const clickedSubFlag = subFlags[index];
    const currentMainFlag = mainFlag;

    // Swap les drapeaux
    setMainFlag(clickedSubFlag);

    const newSubFlags = [...subFlags];
    newSubFlags[index] = currentMainFlag;
    setSubFlags(newSubFlags);

    // Fermer le sélecteur
    setIsLanguageSelectorOpen(false);

    console.log(`Nouvelle langue sélectionnée : ${clickedSubFlag.lang}`);
  };

  // Scroll smooth vers une section avec animation lente personnalisée
  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId);
    const container = document.querySelector('.landing-page');
    if (element && container) {
      const targetPosition = element.offsetTop;
      const startPosition = container.scrollTop;
      const distance = targetPosition - startPosition;
      const duration = 1200; // Durée en ms - plus lent et fluide
      let startTime: number | null = null;

      // Easing function - easeInOutCubic pour une animation très fluide
      const easeInOutCubic = (t: number): number => {
        return t < 0.5
          ? 4 * t * t * t
          : 1 - Math.pow(-2 * t + 2, 3) / 2;
      };

      const animation = (currentTime: number) => {
        if (startTime === null) startTime = currentTime;
        const timeElapsed = currentTime - startTime;
        const progress = Math.min(timeElapsed / duration, 1);
        const easedProgress = easeInOutCubic(progress);

        container.scrollTop = startPosition + distance * easedProgress;

        if (timeElapsed < duration) {
          requestAnimationFrame(animation);
        }
      };

      requestAnimationFrame(animation);
    }
  };

  return (
    <div className="landing-page">
      {/* Language Selector */}
      <div
        id="language-selector"
        className={isLanguageSelectorOpen ? 'open' : ''}
      >
        <div
          className="flag-circle main-flag"
          data-lang={mainFlag.lang}
          data-img={mainFlag.dataImg}
          onClick={handleMainFlagClick}
        >
          <img src={mainFlag.imgSrc} alt={mainFlag.altText} />
        </div>

        <div className="sub-flags">
          {subFlags.map((flag, index) => (
            <div
              key={flag.lang}
              className="flag-circle sub-flag"
              data-lang={flag.lang}
              data-img={flag.dataImg}
              onClick={() => handleSubFlagClick(index)}
            >
              <img src={flag.imgSrc} alt={flag.altText} />
            </div>
          ))}
        </div>
      </div>

      <main className="primary-main">
        {/* Navigation */}
        <nav className="navigation">
          <div className="nav-logo">
            <a
              href="#navigation"
              className="nav-item-link"
              onClick={(e) => { e.preventDefault(); scrollToSection('navigation'); }}
            >
              VEGECE
            </a>
          </div>

          <ul>
            <li className="nav-item">
              <a
                href="#showcase"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('showcase'); }}
              >
                Présentation
              </a>
            </li>
            <li className="nav-item">
              <a
                href="#about"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}
              >
                A propos
              </a>
            </li>
            <li className="nav-item">
              <a
                href="#download"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}
              >
                Téléchargement
              </a>
            </li>
          </ul>

          <div
            className="nav-pro-login"
            style={{ cursor: 'pointer' }}
            onClick={() => navigate('/login')}
          >
            Vous êtes un professionnel ?
          </div>
        </nav>

        {/* Hero Section */}
        <div className="main" id="navigation">
          <span className="main-title">
            VEGECE
          </span>

          <span className="main-slogan">
            La santé de votre animal, simplifiée
          </span>

          <button
            className="main-btn scroll-arrow"
            onClick={() => scrollToSection('showcase')}
            aria-label="Défiler vers le bas"
          >
            <i className="fa-solid fa-chevron-down"></i>
          </button>
        </div>

        {/* Showcase Section */}
        <div className="showcase" id="showcase">
          <div className="page-selector page-selector-pos">
            <div className="selector-bg">
              <div className="selector-active"></div>
              <div className="selector-case"></div>
              <div className="selector-case"></div>
            </div>
          </div>

          <div className="showcase-img">
            <img src="/assets/img/phone.png" alt="" className="showcase-img-size" />
          </div>

          <div className="showcase-desc">
            <span className="showcase-desc-title">
              Titre explication page 1
            </span>
            <span className="showcase-desc-text">
              Lorem ipsum dolor sit amet, consectetur adipiscing elit.<br />
              Donec pharetra diam non tempor bibendum.<br />
              In vestibulum, magna eu blandit viverra, dui arcu vestibulum nisl,<br />
              id pretium tellus neque vitae diam.<br />
              Ut tristique felis ac maximus ullamcorper.<br />
              Fusce lacinia tellus ut ligula viverra blandit.
            </span>
          </div>
        </div>

        {/* About Section */}
        <div className="about" id="about">
          <div className="about-circle-container">
            {/* Phone au centre avec frame iPhone */}
            <div className="about-phone-center">
              <div className="iphone-frame">
                <img src="/assets/img/iphone.png" alt="iPhone Frame" className="iphone-border" />
                <div className="iphone-screen">
                  <img
                    key={animationKey}
                    src={features[selectedFeature].screen}
                    alt={features[selectedFeature].title}
                    className="screen-enter"
                  />
                </div>
              </div>
            </div>

            {/* Features en cercle - rotation */}
            <div className="features-orbit">
              {features.map((feature, index) => (
                <div
                  key={index}
                  className={`about-feature feature-${index + 1} ${selectedFeature === index ? 'active' : ''}`}
                  onClick={() => handleFeatureClick(index)}
                >
                  <div className="feature-icon">
                    <i className={`fa-solid ${feature.icon}`}></i>
                  </div>
                  <div className="feature-content">
                    <span className="feature-title">{feature.title}</span>
                    <span className="feature-desc">{feature.desc}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Download Section */}
        <div className="download" id="download">
          <span className="download-title">
            Titre explication page 3
          </span>
          <span className="download-desc">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit.<br />
            Donec pharetra diam non tempor bibendum.<br />
            In vestibulum, magna eu blandit viverra, dui arcu vestibulum nisl,<br />
            id pretium tellus neque vitae diam.<br />
            Ut tristique felis ac maximus ullamcorper.<br />
            Fusce lacinia tellus ut ligula viverra blandit.
          </span>
          <button className="download-btn">
            Download App
          </button>
          <span className="download-os">
            iOS, Android
          </span>
        </div>

        {/* Footer */}
        <footer className="footer">
          <div className="footer-side-1">
            <div className="footer-logo">
              <i className="fa-solid fa-paw footer-logo-paw"></i>
            </div>
            <span className="footer-name">
              VEGECE<br />
              2025©
            </span>
          </div>

          <div className="footer-side-2">
            <ul className="footer-nav">
              <li className="footer-nav-item">
                <a
                  href="#navigation"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('navigation'); }}
                >
                  Acceuil
                </a>
              </li>
              <li className="footer-nav-item">
                <a
                  href="#showcase"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('showcase'); }}
                >
                  Présentation
                </a>
              </li>
              <li className="footer-nav-item">
                <a
                  href="#about"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}
                >
                  A propos
                </a>
              </li>
              <li className="footer-nav-item">
                <a
                  href="#download"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}
                >
                  Téléchargement
                </a>
              </li>
            </ul>
          </div>

          <div className="footer-side-3">
            <ul className="footer-nav-social">
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-tiktok"></i>
                </a>
              </li>
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-facebook"></i>
                </a>
              </li>
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-x-twitter"></i>
                </a>
              </li>
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-instagram"></i>
                </a>
              </li>
            </ul>
          </div>
        </footer>
      </main>
    </div>
  );
}

export default LandingPage;
