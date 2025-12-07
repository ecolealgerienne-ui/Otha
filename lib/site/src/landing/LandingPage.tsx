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
  const [activeFeature, setActiveFeature] = useState(0);

  // Features data
  const features = [
    {
      icon: 'fa-map-location-dot',
      title: 'Trouvez autour de vous',
      desc: 'Vétérinaires, garderies, pet shops près de chez vous'
    },
    {
      icon: 'fa-paw',
      title: 'Tous vos animaux',
      desc: 'Chiens, chats, NAC... gérez tous vos compagnons'
    },
    {
      icon: 'fa-calendar-check',
      title: 'Rendez-vous facile',
      desc: 'Réservez en quelques clics chez votre vétérinaire'
    },
    {
      icon: 'fa-file-medical',
      title: 'Carnet de santé',
      desc: 'Vaccins, ordonnances, historique médical centralisé'
    },
    {
      icon: 'fa-heart',
      title: 'Adoption',
      desc: 'Trouvez votre futur compagnon ou proposez à l\'adoption'
    },
    {
      icon: 'fa-house',
      title: 'Garderie',
      desc: 'Trouvez une garderie de confiance pour vos absences'
    }
  ];

  // Auto-rotation du carousel
  useEffect(() => {
    const interval = setInterval(() => {
      setActiveFeature((prev) => (prev + 1) % features.length);
    }, 4000);
    return () => clearInterval(interval);
  }, [features.length]);

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

  // Charger FontAwesome et configurer le HTML
  useEffect(() => {
    // Ajouter classe sur html pour le scroll
    document.documentElement.classList.add('landing-active');

    // Charger FontAwesome
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
    document.head.appendChild(link);

    return () => {
      document.documentElement.classList.remove('landing-active');
      document.head.removeChild(link);
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

  // Scroll smooth vers une section
  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
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
            SLOGAN
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

        {/* About Section - Carousel */}
        <div className="about" id="about">
          <div className="about-carousel-container">
            {/* Flèche gauche */}
            <button
              className="carousel-arrow carousel-arrow-left"
              onClick={() => setActiveFeature((prev) => (prev - 1 + features.length) % features.length)}
            >
              <i className="fa-solid fa-chevron-left"></i>
            </button>

            {/* Feature card gauche */}
            <div className="carousel-feature carousel-feature-left">
              <div className="feature-icon">
                <i className={`fa-solid ${features[(activeFeature - 1 + features.length) % features.length].icon}`}></i>
              </div>
              <div className="feature-content">
                <span className="feature-title">{features[(activeFeature - 1 + features.length) % features.length].title}</span>
                <span className="feature-desc">{features[(activeFeature - 1 + features.length) % features.length].desc}</span>
              </div>
            </div>

            {/* Phone au centre */}
            <div className="about-phone-center">
              <img src="/assets/img/phone.png" alt="VEGECE App" />
              {/* Ligne de connexion */}
              <div className="connection-line connection-line-left"></div>
              <div className="connection-line connection-line-right"></div>
            </div>

            {/* Feature card droite */}
            <div className="carousel-feature carousel-feature-right">
              <div className="feature-icon">
                <i className={`fa-solid ${features[(activeFeature + 1) % features.length].icon}`}></i>
              </div>
              <div className="feature-content">
                <span className="feature-title">{features[(activeFeature + 1) % features.length].title}</span>
                <span className="feature-desc">{features[(activeFeature + 1) % features.length].desc}</span>
              </div>
            </div>

            {/* Flèche droite */}
            <button
              className="carousel-arrow carousel-arrow-right"
              onClick={() => setActiveFeature((prev) => (prev + 1) % features.length)}
            >
              <i className="fa-solid fa-chevron-right"></i>
            </button>

            {/* Feature active en haut */}
            <div className="carousel-feature-active">
              <div className="feature-icon-large">
                <i className={`fa-solid ${features[activeFeature].icon}`}></i>
              </div>
              <span className="feature-title-large">{features[activeFeature].title}</span>
              <span className="feature-desc-large">{features[activeFeature].desc}</span>
            </div>

            {/* Dots de navigation */}
            <div className="carousel-dots">
              {features.map((_, index) => (
                <button
                  key={index}
                  className={`carousel-dot ${index === activeFeature ? 'active' : ''}`}
                  onClick={() => setActiveFeature(index)}
                />
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
