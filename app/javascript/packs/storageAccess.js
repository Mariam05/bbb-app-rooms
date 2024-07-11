
var isFirefox = navigator.userAgent.indexOf("Firefox") != -1;
var isSafari = /constructor/i.test(window.HTMLElement) || (function (p) { return p.toString() === "[object SafariRemoteNotification]"; })(!window['safari'] || (typeof safari !== 'undefined' && window['safari'].pushNotification));


console.log("Firefox? " + isFirefox + " Safari? " + isSafari);


async function handleCookieAccess(){
	if (!document.hasStorageAccess) {
		// This browser doesn't support the Storage Access API
    // so let's just hope we have access!

		console.warn("Browser does not support the Storage Access API")
	} else {
		const hasAccess = await document.hasStorageAccess();
		if (hasAccess) {
			console.log("We have access to third-party cookies")
			// We have access to third-party cookies, so let's go
			// If we want to modify unpartitioned state, we need to request a handle.
			// This handle must be used to set localStorage items.
      const handle = await document.requestStorageAccess({
        localStorage: true,
				sessionStorage: true,
      });
    } else {
      // Check whether third-party cookie access has been granted
      // to another same-site embed
      try {
        const permission = await navigator.permissions.query({
          name: "storage-access",
        });

				console.log("Permission state: ", permission.state)
        if (permission.state === "granted") {
					console.log("third-party cookie access has been granted to another same-site embed");
          // If so, you can just call requestStorageAccess() without a user interaction,
          // and it will resolve automatically.
          const handle = await document.requestStorageAccess({
            cookies: true,
            localStorage: true,
						sessionStorage: true,
          });
          // doThingsWithLocalStorage(handle);
          // doThingsWithCookies();
        } else if (permission.state === "prompt") {
					$('#access-alert').show();
          // Need to call requestStorageAccess() after a user interaction
          $('#accept-btn').on("click", async () => {
            try {
              const handle = await document.requestStorageAccess({
                cookies: true,
                localStorage: true,
								sessionStorage: true,
              });
							const permission = await navigator.permissions.query({
								name: "storage-access",
							});
							if (permission.state = "granted") {
								$('#accept-btn').hide();
								$('#access-alert').hide();
							}
            } catch (err) {
              // If there is an error obtaining storage access.
              console.error(`Error obtaining storage access: ${err}.
                            Please sign in.`);
            }
          });
        } else if (permission.state === "denied") {
          // User has denied third-party cookie access, so we'll
          // need to do something else
					console.log("User has denied third-party cookie access")
        }
      } catch (error) {
        console.log(`Could not access permission state. Error: ${error}`);
        // doThingsWithCookies(); // Again, we'll have to hope we have access!
      }
		}
	}

}

handleCookieAccess();

/*
With Dynamic State Partitioning enabled, Firefox provides embedded resources with a separate storage bucket for every top-level website, causing the request to be denied if it comes from a third party. Embedded third-parties may request access to the top-level storage bucket, which is what we're doing with the requestAccess() method.
*/


/*
function requestAccess() {
		document.requestStorageAccess().then(
				() => {
						console.log('access granted!');
						$('#access-alert').hide();
						// the user needs to reload and then press the button again for it to work 
				},
				() => { console.log('access denied') }
		);
}

if (isFirefox || isSafari) {
		document.hasStorageAccess().then((hasAccess) => {
				if (!hasAccess && (isFirefox || isSafari)) {
						$('#access-alert').show();
						console.log("no access");

				} else {
						console.log("Already has access");
				}
		});
}

$('#accept-btn').on('click', requestAccess);
*/