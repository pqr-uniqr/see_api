//
//  ViewController.swift
//  see_api
//
//  Created by Pete Kim on 3/12/15.
//  Copyright (c) 2015 Pete Kim. All rights reserved.
//

import UIKit
import Foundation
import Parse
import Bolts

class MainViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.galleriesAndCompetitionsAndSubmissions(true).continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      self.globalUpdate()
      return nil
    })
  }
  
  override func viewWillAppear(animated: Bool) {
    self.navigationController?.navigationBarHidden = true
    self.galleriesAndCompetitionsAndSubmissions(false).continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      self.globalUpdate()
      return nil
    })
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  // sync gallery object between server and client
  func globalUpdate(){
    let serverQuery = PFQuery(className: "Gallery");
    
    serverQuery.findObjectsInBackground().continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      
      let galleries = task.result as [AnyObject]
      if galleries.count == 0 {
        return BFTask(error: NSError(domain: "no gallery found", code: -1, userInfo: nil));
      }
      let gallery = galleries[0] as PFObject
      printGallery(gallery)
      
      let localQuery = PFQuery(className: "Gallery_local").fromLocalDatastore()
      return localQuery.findObjectsInBackground().continueWithBlock({
        (task: BFTask!) -> AnyObject! in
        
        let localGalleries = task.result as [AnyObject]
        if localGalleries.count == 0 {
          // no local galleries -- create one
          println("no local galleries--creating one")
          let localGallery = PFObject(className: "Gallery_local");
          localGallery["galleryId"] = gallery.objectId
          localGallery["name"] = gallery["name"] as String
          localGallery["latestCompetition"] = gallery["latestCompetition"] as String
          localGallery["competitionActive"] = gallery["competitionActive"] as Bool
          localGallery.pinInBackground()
          return BFTask(result: nil)
        }
        
        println("number of galleries in local datastore \(localGalleries.count)")
        
        // check local gallery is the correct one and update
        println("local gallery found -- updating info")
        
        let localGallery = localGalleries[0] as PFObject
        if localGallery["galleryId"] as String == gallery.objectId {
          localGallery["name"] = gallery["name"] as String
          localGallery["latestCompetition"] = gallery["latestCompetition"] as String
          localGallery["competitionActive"] = gallery["competitionActive"] as Bool
          
          localGallery.pinInBackground()
          return BFTask(result: nil)
        } else {
          return BFTask(error: NSError(domain: "gallery id doesn't match up",
            code: -1, userInfo: nil))
        }
      })
    }).continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      println("wrapping up global update")
      if task.error != nil {
        println("something went wrong: \(task.error)")
      } else {
        println("all good")
      }
      
      return nil;
    })
  }
  
  
  
  
  
  // testing methods-------
  
  func galleriesAndCompetitionsAndSubmissions(reset: Bool) -> BFTask! {
    println("local data check called (reset? \(reset))")
    
    let taskSource = BFTaskCompletionSource()
    
    let query = PFQuery(className: "Competition_local").fromLocalDatastore()
    query.findObjectsInBackground().continueWithSuccessBlock({
      (task: BFTask!) -> AnyObject! in
      
      let competitions = task.result as [PFObject]!
      if competitions.count > 0 {
        println("local copies of competition found")
      }
      
      for competition in competitions {
        let competitionId = competition["competitionId"] as String!
        println("competition id: \(competitionId)")
        if reset {
          competition.unpin()
        }
      }
      
      let galleryQuery = PFQuery(className: "Gallery_local").fromLocalDatastore()
      return galleryQuery.findObjectsInBackground()
    }).continueWithSuccessBlock({
      (task: BFTask!) -> AnyObject! in
      
      var galleries = task.result as [PFObject]!
      if galleries.count > 0 {
        println("local copies of gallery found")
      }
      for gallery in galleries {
        let galleryName = gallery["name"] as String!
        println("gallery name: \(galleryName)")
        if reset {
          gallery.unpin()
        }
      }
      
      let submissionQuery = PFQuery(className: "Submission_local").fromLocalDatastore()
      return submissionQuery.findObjectsInBackground()
    }).continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      var submissions = task.result as [PFObject]!
      if submissions.count > 0 {
        println("local copies of gallery found")
      }
      for submission in submissions {
        let submissionId = submission["submissionId"] as String!
        println("submission id: \(submissionId)")
        if reset {
          submission.unpin()
        }
      }
      taskSource.setResult(nil)
      return nil
    })
    
    return taskSource.task
  }
  
  func testAsync() -> BFTask! {
    println("testAsync called")
    let taskSource = BFTaskCompletionSource() as BFTaskCompletionSource
    
    let query = PFQuery(className: "Competition")
    query.addDescendingOrder("endDate")
    query.whereKey("gallery", equalTo: "abc")
    query.getFirstObjectInBackground().continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      println("query 1 finished running")
      return nil
    })
    
    let query2 = PFQuery(className: "Competition")
    query2.addDescendingOrder("endDate")
    query2.whereKey("gallery", equalTo: "abc")
    query2.getFirstObjectInBackground().continueWithBlock({
      (task: BFTask!) -> AnyObject! in
      // above task is from the previous task
      // function in continueWithBlock will only be called when getFirstObjectInBackground is done
      // if you call continueWithBlock on a returned
      
      println("query 2 finished running")
      let latestCompetition = task.result as PFObject!
      if latestCompetition == nil {
        taskSource.setError(NSError(domain: "no competition found", code: -1, userInfo: nil))
        return nil
      }
      let secondQuery = PFQuery(className: "Submission")
      return query.getFirstObjectInBackground().continueWithBlock({
        (task: BFTask!) -> AnyObject! in
        let submission = task.result as PFObject!
        if submission == nil {
          taskSource.setError(NSError(domain: "no submission found", code: -1, userInfo: nil))
          return nil
        }
        
        taskSource.setResult(submission)
        return nil
      })
    })
    return taskSource.task
  }
}
