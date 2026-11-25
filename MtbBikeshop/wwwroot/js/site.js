// Please see documentation at https://learn.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

function showUnavailableBikePhoto(image) {
    image.hidden = true;
    image.parentElement.querySelector('.bike-photo-unavailable').hidden = false;
}

document.querySelectorAll('.bike-photo img').forEach(image => {
    image.addEventListener('error', () => showUnavailableBikePhoto(image));
    if (image.complete && image.naturalWidth === 0) {
        showUnavailableBikePhoto(image);
    }
});
