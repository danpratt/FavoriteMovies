//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        configureUI()
        
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    
    // MARK: error handling
    private func displayError(error: String) {
        print(error)
        performUIUpdatesOnMain {
            self.setUIEnabled(true)
            self.debugTextLabel.text = "Login Failed"
        }
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "MoviesTabBarController") as! UITabBarController
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            /* GUARD: Check for error */
            guard (error == nil) else {
                self.displayError(error: "There was an error with your request: \(error)")
                return
            }
        
            /* GUARD: Check status code */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                self.displayError(error: "Your request returned a status code other than successful.  Expected 2xx")
                return
            }
            
            /* 5. Parse the data */
            
            /* GUARD: Get data */
            // This should always work if the status code guard passes
            guard let data = data else {
                self.displayError(error: "No data was returned")
                return
            }
            
            // Convert data into JSON
            let responseJSONData: [String:AnyObject]!
            do {
                responseJSONData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                self.displayError(error: "Could not convert data to JSON")
                return
            }
            
            /* GUARD: Extract Request token */
            guard let request_token = responseJSONData[Constants.TMDBResponseKeys.RequestToken] as? String else {
                self.displayError(error: "Error getting request token from JSON")
                return
            }
            
            /* 6. Use the data! */
            self.appDelegate.requestToken = request_token
            self.loginWithToken(request_token)

        }

        /* 7. Start the request */
        task.resume()
    }
    
    // Logs in, uses request_token to match API documentation
    private func loginWithToken(_ request_token: String) {
        
        
        /* TASK: Login, then get a session id */
        guard let username = usernameTextField.text, let password = passwordTextField.text else {
            displayError(error: "Unable to get username or password")
            return
        }
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey:Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.Username:username,
            Constants.TMDBParameterKeys.Password:password,
            Constants.TMDBParameterKeys.RequestToken:request_token
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/authentication/token/validate_with_login"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) {
            (data, response, error) in
            
            /* GUARD: check if there was an error */
            guard (error == nil) else {
                self.displayError(error: "There was an erorr \(error)")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                self.displayError(error: "Status code is other than successful.  Expected 2xx")
                return
            }
            
            guard let data = data else {
                self.displayError(error: "Error retreiving data from request")
                return
            }
            
            /* 5. Parse the data */
            
            let requestJSONData: [String:AnyObject]!
            do {
                requestJSONData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            }
            catch {
                self.displayError(error: "Could not convert data to JSON")
                return
            }
            
            
            guard (requestJSONData[Constants.TMDBResponseKeys.Success] as! Bool), let response_token = requestJSONData[Constants.TMDBResponseKeys.RequestToken] as? String else {
                self.displayError(error: "Unable to extract responst_token")
                return
                }
            
            /* 6. Use the data! */
            self.getSessionID(response_token)
            }
        
        
        /* 7. Start the request */
        
        task.resume()
    }
    
    private func getSessionID(_ request_token: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        
        /* 1. Set the parameters */
        
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey:Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.RequestToken:request_token
        ]
        
        /* 2/3. Build the URL, Configure the request */
        
        /* 4. Make the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/authentication/session/new"))
        
        let task = appDelegate.sharedSession.dataTask(with: request) {
            (data, response, error) in
            
            /* GUARD: Check for error */
            guard (error == nil) else {
                self.displayError(error: "There was an error \(error)")
                return
            }
            
            /* GUARD: Check valid status response */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                self.displayError(error: "Got other than successful status code")
                return
            }
            
            /* GUARD: Get data */
            guard let data = data else {
                self.displayError(error: "Could not get data")
                return
            }
            
            /* 5. Parse the data */
            let sessionJSONData: [String:AnyObject]!
            do {
                sessionJSONData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String : AnyObject]
            } catch {
                self.displayError(error: "Unable to extract JSON format from data")
                return
            }
            
            /* 6. Use the data! */
            
            /* GUARD: Check success and get ID */
            guard (sessionJSONData[Constants.TMDBResponseKeys.Success] as? Bool)!, let session_id = sessionJSONData[Constants.TMDBResponseKeys.SessionID] as? String else {
                self.displayError(error: "Unable to get session_id")
                return
            }
            
            self.appDelegate.sessionID = session_id
            self.getUserID(session_id)
        }
        
        
        
        /* 7. Start the request */
        task.resume()
    }
    
    // Get and save userID to appDelegate Singleton
    private func getUserID(_ session_id: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        /* 1. Set the parameters */
        
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey:Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.SessionID:session_id
        ]
        
        /* 2/3. Build the URL, Configure the request */
        
        /* 4. Make the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/account"))
        
        let task = appDelegate.sharedSession.dataTask(with: request) {
            (data, response, error) in
            
            /* GUARD: Check for error */
            guard (error == nil) else {
                self.displayError(error: "There was an error while getting username.  \(error)")
                return
            }
            
            /* GUARD: Check status */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                self.displayError(error: "Status Code returned other than sucess.  Expected 2xx")
                return
            }
            
            /* GUARD: Get the data */
            guard let data = data else {
                self.displayError(error: "Unable to retrieve data")
                return
            }
            
            /* 5. Parse the data */
            
            // Convert to JSON
            let accountJSONData: [String:AnyObject]
            do {
                accountJSONData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                self.displayError(error: "Unable to convert data to JSON format")
                return
            }
            
            /* GUARD: Get username */
            guard let user_id = accountJSONData[Constants.TMDBResponseKeys.UserID] as? Int else {
                self.displayError(error: "Unable to get user ID")
                return
            }
            
            /* 6. Use the data! */
            print("successful login")
            self.appDelegate.userID = user_id
            self.completeLogin()
        }
        
        
        /* 7. Start the request */
        task.resume()
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.isHidden = true
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.isHidden = false
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    private func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

private extension LoginViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        usernameTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        loginButton.isEnabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.isEnabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    func configureTextField(_ textField: UITextField) {
        let textFieldPaddingViewFrame = CGRect(x: 0.0, y: 0.0, width: 13.0, height: 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSForegroundColorAttributeName: UIColor.white])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

private extension LoginViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
