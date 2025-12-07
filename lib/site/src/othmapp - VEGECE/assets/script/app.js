document.addEventListener('DOMContentLoaded', () => {
    const selector = document.getElementById('language-selector');
    const mainFlag = selector.querySelector('.main-flag');
    const subFlagsContainer = selector.querySelector('.sub-flags');
    const allSubFlags = selector.querySelectorAll('.sub-flag');

    // 1. Fonction pour ouvrir/fermer le sélecteur (quand on clique sur le drapeau principal)
    mainFlag.addEventListener('click', () => {
        // Toggle la classe 'open' : si elle est là, on l'enlève ; sinon, on la met.
        selector.classList.toggle('open');
    });

    // 2. Fonction pour changer de langue (quand on clique sur un sous-drapeau)
    allSubFlags.forEach(subFlag => {
        subFlag.addEventListener('click', () => {
            
            // a. Récupérer les données de la nouvelle langue
            const newLangData = {
                lang: subFlag.dataset.lang,
                imgSrc: subFlag.querySelector('img').src,
                altText: subFlag.querySelector('img').alt,
                dataImg: subFlag.dataset.img
            };

            // b. Récupérer les données de la langue actuelle (celle du mainFlag)
            const currentLangData = {
                lang: mainFlag.dataset.lang,
                imgSrc: mainFlag.querySelector('img').src,
                altText: mainFlag.querySelector('img').alt,
                dataImg: mainFlag.dataset.img
            };

            // c. Faire l'échange de contenu (SWAP)
            
            // Le mainFlag prend le contenu du sous-drapeau cliqué
            mainFlag.dataset.lang = newLangData.lang;
            mainFlag.dataset.img = newLangData.dataImg;
            mainFlag.querySelector('img').src = newLangData.imgSrc;
            mainFlag.querySelector('img').alt = newLangData.altText;

            // Le sous-drapeau cliqué prend le contenu de l'ancien mainFlag
            subFlag.dataset.lang = currentLangData.lang;
            subFlag.dataset.img = currentLangData.dataImg;
            subFlag.querySelector('img').src = currentLangData.imgSrc;
            subFlag.querySelector('img').alt = currentLangData.altText;

            // d. Fermer le sélecteur après le changement
            selector.classList.remove('open');

            // e. Ici, tu peux appeler ta fonction de traduction du site !
            // Par exemple : updateWebsiteLanguage(newLangData.lang);
            console.log(`Nouvelle langue sélectionnée : ${newLangData.lang}`);
        });
    });
});