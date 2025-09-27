const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

// Configura SendGrid con la API key que guardaste
// en el gestor de secretos de Firebase.
const SENDGRID_API_KEY = functions.config().sendgrid.key;
sgMail.setApiKey(SENDGRID_API_KEY);

// Tu función de envío de correo
exports.enviarCorreoDeBienvenida = functions.auth.user().onCreate((user) => {
  const email = user.email;
  const displayName = user.displayName || "Usuario";

  const msg = {
    to: email,
    from: "rutaU@gmail.com", // Reemplaza con tu correo verificado en SendGrid
    subject: "¡Gracias por registrarte a Ruta U!",
    html: `
      <h1>¡Hola, ${displayName}!</h1>
      <p>
        ¡Hola! Gracias por registrarte a Ruta U, de acuerdo al rol
        que elijas podrás acceder a nuestras funcionalidades.
        Estamos emocionados de tenerte a bordo y esperamos que
        disfrutes de la experiencia. Si tienes alguna pregunta o
        necesitas ayuda, no dudes en contactarnos.
        <br><br>
        ¡Bienvenido a la comunidad de Ruta U!
        <br><br>
        Saludos cordiales,
        <br>
        El equipo de Ruta U
      </p>
    `,
  };

  return sgMail
      .send(msg)
      .then(() => {
        console.log("Correo de bienvenida enviado a", email);
        return null;
      })
      .catch((error) => {
        console.error("Error al enviar el correo:", error);
      });
});
